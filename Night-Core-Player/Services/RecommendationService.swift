import Foundation
import MusicKit

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

    // 同日中はメモリキャッシュを再利用する (アプリ再起動で再生成。永続化は見送り)
    private var cachedDay: Date?
    private var cachedQueue: [Song] = []

    init(client: MusicKitClient, calendar: Calendar = .current) {
        self.client = client
        self.calendar = calendar
    }

    func buildDailyQueue(history: [Song], limit: Int) async -> [Song] {
        let today = calendar.startOfDay(for: Date())
        if cachedDay == today, !cachedQueue.isEmpty {
            return Array(cachedQueue.prefix(limit))
        }

        let queue = await compose(history: history, limit: limit)
        if !queue.isEmpty {
            cachedDay = today
            cachedQueue = queue
        }
        return queue
    }

    // MARK: - 配合

    private func compose(history: [Song], limit: Int) async -> [Song] {
        // ソース収集: ローカル履歴 + MusicKit の再生履歴 (取れなければ履歴のみで続行)
        let recent = (try? await client.fetchRecentlyPlayedSongs(
            limit: Constants.Recommendation.recentlyPlayedFetchLimit
        )) ?? []
        let sources = history + recent
        guard !sources.isEmpty else { return [] }

        let knownIDs = Set(sources.map(\.id))
        let topArtists = await resolveTopArtists(from: sources)

        let discoveryTarget = Int(Double(limit) * Constants.Recommendation.discoveryRatio)
        let discoveries = await collectDiscoveries(
            around: topArtists, excluding: knownIDs, target: discoveryTarget
        )
        let familiar = await collectFamiliar(
            from: sources, artists: topArtists, limit: limit
        )

        // C を limit - D 件に抑えて合成。どちらかが不足したら他方で埋める
        var result = Array(familiar.prefix(limit - discoveries.count))
        result.append(contentsOf: discoveries)
        if result.count < limit {
            let usedIDs = Set(result.map(\.id))
            result.append(contentsOf: familiar.filter { !usedIDs.contains($0.id) }.prefix(limit - result.count))
        }
        return dedupeByID(result).shuffled()
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

        for artist in artists where pool.count < limit {
            let tops = (try? await client.fetchArtistTopSongs(artist: artist)) ?? []
            pool.append(contentsOf: tops)
        }
        return dedupeByID(pool)
    }

    /// D: 上位アーティストの similarArtists → topSongs から未聴曲だけ
    private func collectDiscoveries(
        around artists: [Artist], excluding knownIDs: Set<MusicItemID>, target: Int
    ) async -> [Song] {
        guard target > 0 else { return [] }
        var pool: [Song] = []
        for artist in artists {
            let similars = (try? await client.fetchSimilarArtists(artist: artist)) ?? []
            for similar in similars.prefix(Constants.Recommendation.similarArtistsPerArtist) {
                let tops = (try? await client.fetchArtistTopSongs(artist: similar)) ?? []
                pool.append(contentsOf: tops.filter { !knownIDs.contains($0.id) })
                if pool.count >= target { break }
            }
            if pool.count >= target { break }
        }
        return Array(dedupeByID(pool).prefix(target))
    }

    /// 頻度上位のアーティスト名を Artist に解決する (Song から Artist は直接取れないため検索で引く)
    private func resolveTopArtists(from sources: [Song]) async -> [Artist] {
        let counts: [String: Int] = sources.reduce(into: [:]) { $0[$1.artistName, default: 0] += 1 }
        let names = counts.sorted { $0.value > $1.value }
            .prefix(Constants.Recommendation.topArtistCount)
            .map(\.key)

        var artists: [Artist] = []
        for name in names {
            if let artist = try? await client.searchCatalogArtists(term: name, limit: 1).first {
                artists.append(artist)
            }
        }
        return artists
    }

    private func dedupeByID(_ songs: [Song]) -> [Song] {
        var seen = Set<MusicItemID>()
        return songs.filter { seen.insert($0.id).inserted }
    }
}
