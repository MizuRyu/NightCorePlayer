import Foundation
import MusicKit
import OSLog

// MARK: - Protocol

/// 聴取実績から自動レコメンドキューを組み立てる (docs/specs/RECOMMENDATION.md)
protocol RecommendationBuilding: Sendable {
    /// 履歴ベース + 類似探索の配合で最大 limit 曲を返す。素材が全く無ければ空配列
    func buildDailyQueue(history: [Song], limit: Int) async -> [Song]
}

// MARK: - Impl

actor RecommendationServiceImpl: RecommendationBuilding {
    private let client: MusicKitClient
    private let calendar: Calendar
    private let logger = Logger(subsystem: Constants.Logging.subsystem, category: "Recommendation")

    // 同日・同 limit はメモリキャッシュを再利用する (アプリ再起動で再生成。永続化は見送り)。
    // API 失敗を含む縮退結果はキャッシュしない (復旧後の再試行を妨げないため)
    private struct CacheKey: Equatable {
        let day: Date
        let limit: Int
    }
    private var cacheKey: CacheKey?
    private var cachedQueue: [Song] = []
    // 同時初回呼び出しの single-flight (actor は await 中に再入可能なため)
    private var inFlight: [Int: Task<ComposeResult, Never>] = [:]

    private struct ComposeResult {
        let songs: [Song]
        // 素材系 API のいずれかが失敗したまま組んだ結果か (キャッシュ可否の判定に使う)
        let degraded: Bool
    }

    init(client: MusicKitClient, calendar: Calendar = .current) {
        self.client = client
        self.calendar = calendar
    }

    func buildDailyQueue(history: [Song], limit: Int) async -> [Song] {
        let today = calendar.startOfDay(for: Date())
        if cacheKey == CacheKey(day: today, limit: limit), !cachedQueue.isEmpty {
            return cachedQueue
        }

        if let running = inFlight[limit] {
            return await running.value.songs
        }
        let task = Task { await self.compose(history: history, limit: limit) }
        inFlight[limit] = task
        let result = await task.value
        inFlight[limit] = nil

        if !result.songs.isEmpty, !result.degraded {
            cacheKey = CacheKey(day: today, limit: limit)
            cachedQueue = result.songs
        }
        return result.songs
    }

    // MARK: - 配合

    private func compose(history: [Song], limit: Int) async -> ComposeResult {
        var degraded = false

        // ソース収集: ローカル履歴 + MusicKit の再生履歴 (取れなければ履歴のみで続行)
        var recent: [Song] = []
        do {
            recent = try await client.fetchRecentlyPlayedSongs(
                limit: Constants.Recommendation.recentlyPlayedFetchLimit
            )
        } catch {
            degraded = true
            logger.warning("fetchRecentlyPlayedSongs failed: \(error.localizedDescription)")
        }
        let sources = history + recent
        guard !sources.isEmpty, !Task.isCancelled else {
            return ComposeResult(songs: [], degraded: degraded || Task.isCancelled)
        }

        let knownIDs = Set(sources.map(\.id))
        let (topArtists, artistsDegraded) = await resolveTopArtists(from: sources)

        let familiar = await collectFamiliar(from: sources, artists: topArtists, limit: limit)
        let familiarIDs = Set(familiar.map(\.id))

        // D は本来 3割。C が不足するときは D で埋められるだけ広げる
        let discoveryTarget = Int(Double(limit) * Constants.Recommendation.discoveryRatio)
        let discoveryNeeded = max(discoveryTarget, limit - familiar.count)
        let discoveries = await collectDiscoveries(
            around: topArtists,
            excluding: knownIDs.union(familiarIDs),
            target: discoveryNeeded
        )

        // C/D は互いに素かつ各プール内 dedupe 済みなので、件数決定後に縮まない
        let discoveryCount = min(discoveries.count, discoveryNeeded)
        var songs = Array(familiar.prefix(limit - discoveryCount))
        songs.append(contentsOf: discoveries.prefix(discoveryCount))

        return ComposeResult(
            songs: songs.shuffled(),
            degraded: degraded || artistsDegraded || Task.isCancelled
        )
    }

    /// C: 高頻度曲 (曲単位の出現回数順) + 上位アーティストの topSongs
    private func collectFamiliar(from sources: [Song], artists: [Artist], limit: Int) async -> [Song] {
        var counts: [MusicItemID: Int] = [:]
        var representatives: [MusicItemID: Song] = [:]
        for song in sources {
            counts[song.id, default: 0] += 1
            representatives[song.id] = song
        }
        var pool = counts
            .sorted { $0.value > $1.value }
            .compactMap { representatives[$0.key] }

        for artist in artists where pool.count < limit && !Task.isCancelled {
            do {
                pool.append(contentsOf: try await client.fetchArtistTopSongs(artist: artist))
            } catch {
                logger.warning("fetchArtistTopSongs(\(artist.name)) failed: \(error.localizedDescription)")
            }
        }
        return dedupeByID(pool)
    }

    /// D: 上位アーティストの similarArtists → topSongs から未聴曲だけ (アーティスト単位で並列)
    private func collectDiscoveries(
        around artists: [Artist], excluding knownIDs: Set<MusicItemID>, target: Int
    ) async -> [Song] {
        guard target > 0, !artists.isEmpty else { return [] }

        let found = await withTaskGroup(of: [Song].self) { group in
            for artist in artists {
                group.addTask {
                    await self.discoverSongs(around: artist, excluding: knownIDs, target: target)
                }
            }
            var merged: [Song] = []
            for await songs in group {
                merged.append(contentsOf: songs)
            }
            return merged
        }
        return Array(dedupeByID(found).prefix(target))
    }

    private func discoverSongs(
        around artist: Artist, excluding knownIDs: Set<MusicItemID>, target: Int
    ) async -> [Song] {
        var similars: [Artist] = []
        do {
            similars = try await client.fetchSimilarArtists(artist: artist)
        } catch {
            logger.warning("fetchSimilarArtists(\(artist.name)) failed: \(error.localizedDescription)")
            return []
        }

        var songs: [Song] = []
        for similar in similars.prefix(Constants.Recommendation.similarArtistsPerArtist) {
            guard !Task.isCancelled, songs.count < target else { break }
            do {
                let tops = try await client.fetchArtistTopSongs(artist: similar)
                songs.append(contentsOf: tops.filter { !knownIDs.contains($0.id) })
            } catch {
                logger.warning("fetchArtistTopSongs(\(similar.name)) failed: \(error.localizedDescription)")
            }
        }
        return songs
    }

    /// 頻度上位のアーティスト名を Artist に解決する (Song から Artist は直接取れないため検索で引く。並列)
    private func resolveTopArtists(from sources: [Song]) async -> ([Artist], degraded: Bool) {
        let counts: [String: Int] = sources.reduce(into: [:]) { $0[$1.artistName, default: 0] += 1 }
        let names = counts.sorted { $0.value > $1.value }
            .prefix(Constants.Recommendation.topArtistCount)
            .map(\.key)

        let results = await withTaskGroup(of: (Int, Artist?, Bool).self) { group in
            for (index, name) in names.enumerated() {
                group.addTask {
                    do {
                        let artist = try await self.client.searchCatalogArtists(term: name, limit: 1).first
                        return (index, artist, false)
                    } catch {
                        await self.logSearchFailure(name: name, error: error)
                        return (index, nil, true)
                    }
                }
            }
            var collected: [(Int, Artist?, Bool)] = []
            for await result in group {
                collected.append(result)
            }
            return collected
        }
        // 頻度順を保つ (task group の完了順は不定)
        let artists = results.sorted { $0.0 < $1.0 }.compactMap(\.1)
        let degraded = results.contains { $0.2 }
        return (artists, degraded)
    }

    private func logSearchFailure(name: String, error: Error) {
        logger.warning("searchCatalogArtists(\(name)) failed: \(error.localizedDescription)")
    }

    private func dedupeByID(_ songs: [Song]) -> [Song] {
        var seen = Set<MusicItemID>()
        return songs.filter { seen.insert($0.id).inserted }
    }
}
