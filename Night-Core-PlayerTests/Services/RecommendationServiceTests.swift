import Testing
import Foundation
import MusicKit
@testable import Night_Core_Player

// MARK: - Helpers

/// アーティスト名を指定できるダミー曲 (makeDummySong は DummyArtist 固定のため)
private func makeSong(id: String, artist: String) -> Song {
    let data = """
    {
      "id":"\(id)",
      "type":"songs",
      "attributes": {
        "title":"Song \(id)",
        "artistName":"\(artist)",
        "durationInMillis":180000,
        "playParams": { "kind": "song", "catalogId": "\(id)", "id": "\(id)" }
      }
    }
    """.data(using: .utf8)!
    // swiftlint:disable:next force_try
    return try! JSONDecoder().decode(Song.self, from: data)
}

private struct Fixture {
    let client = MusicKitClientMock()
    let service: RecommendationServiceImpl

    /// 履歴: FavArtist を高頻度で聴いている。similar 経由で未聴曲が取れる状態を既定にする
    init(similarTopSongs: [Song] = (0..<10).map { makeSong(id: "D\($0)", artist: "SimilarArtist") }) {
        client.artistSearchResult = [makeDummyArtist(id: "AR-FAV", name: "FavArtist")]
        client.similarArtists = [makeDummyArtist(id: "AR-SIM", name: "SimilarArtist")]
        client.artistTopSongsByID = [
            "AR-FAV": (0..<10).map { makeSong(id: "C\($0)", artist: "FavArtist") },
            "AR-SIM": similarTopSongs
        ]
        service = RecommendationServiceImpl(client: client)
    }

    static func history(count: Int = 12) -> [Song] {
        (0..<count).map { makeSong(id: "H\($0 % 4)", artist: "FavArtist") }
    }
}

// MARK: - Tests

@Suite("RecommendationService")
struct RecommendationServiceTests {

    @Test("履歴+探索で指定数を返し、探索枠(3割)は未聴曲だけになる")
    func mixRatio() async throws {
        let fx = Fixture()
        let result = await fx.service.buildDailyQueue(history: Fixture.history(), limit: 20)

        #expect(result.count == 20)
        let ids = Set(result.map(\.id.rawValue))
        #expect(ids.count == 20)

        let discoveries = result.filter { $0.id.rawValue.hasPrefix("D") }
        #expect(discoveries.count == 6)
        // 探索枠に既聴曲 (H*) が混ざらない
        #expect(discoveries.allSatisfy { !$0.id.rawValue.hasPrefix("H") })
    }

    @Test("similarArtists が失敗したら履歴系だけで埋める")
    func fallbackToFamiliarOnly() async throws {
        let fx = Fixture()
        fx.client.similarArtistsError = NSError(domain: "test", code: 1)
        let result = await fx.service.buildDailyQueue(history: Fixture.history(), limit: 20)

        #expect(!result.isEmpty)
        #expect(result.allSatisfy { !$0.id.rawValue.hasPrefix("D") })
    }

    @Test("MusicKit 履歴が失敗してもローカル履歴だけで生成できる")
    func recentlyPlayedFailure() async throws {
        let fx = Fixture()
        fx.client.recentlyPlayedError = NSError(domain: "test", code: 1)
        let result = await fx.service.buildDailyQueue(history: Fixture.history(), limit: 20)

        #expect(!result.isEmpty)
    }

    @Test("素材ゼロ (履歴なし・MusicKit履歴も空) なら空配列")
    func emptySources() async throws {
        let fx = Fixture()
        let result = await fx.service.buildDailyQueue(history: [], limit: 20)

        #expect(result.isEmpty)
        // 素材が無い場合は探索 API を呼ばない
        #expect(fx.client.fetchSimilarArtistsCalls == 0)
    }

    @Test("素材が limit 未満でも壊れず、あるだけ返す")
    func shortSources() async throws {
        let fx = Fixture(similarTopSongs: [])
        fx.client.artistTopSongsByID["AR-FAV"] = []
        let result = await fx.service.buildDailyQueue(history: Fixture.history(count: 3), limit: 20)

        // 履歴3件はユニーク曲 H0-H2 の3曲
        #expect(result.count == 3)
    }

    @Test("同日2回目はキャッシュを返し、API を再呼び出ししない")
    func dailyCache() async throws {
        let fx = Fixture()
        let first = await fx.service.buildDailyQueue(history: Fixture.history(), limit: 20)
        let callsAfterFirst = fx.client.fetchRecentlyPlayedCalls
        let second = await fx.service.buildDailyQueue(history: Fixture.history(), limit: 20)

        #expect(fx.client.fetchRecentlyPlayedCalls == callsAfterFirst)
        #expect(Set(first.map(\.id)) == Set(second.map(\.id)))
    }

    @Test("MusicKit の再生履歴も頻度ソースに合算される")
    func recentlyPlayedMerged() async throws {
        let fx = Fixture()
        fx.client.recentlyPlayedSongs = (0..<5).map { makeSong(id: "R\($0)", artist: "FavArtist") }
        let result = await fx.service.buildDailyQueue(history: [], limit: 20)

        // ローカル履歴が空でも MusicKit 履歴から生成できる
        #expect(!result.isEmpty)
        #expect(result.contains { $0.id.rawValue.hasPrefix("R") })
    }
}

// MARK: - MusicKitServiceImpl 統合 (フォールバック)

@Suite("MusicKitServiceImpl レコメンドフォールバック")
struct MusicKitServiceRecommendationFallbackTests {

    @Test("レコメンドが空ならライブラリシャッフルに落ちる")
    func libraryFallback() async throws {
        let client = MusicKitClientMock()
        client.playlists = [makeDummyPlaylist(id: "PL1")]
        client.playlistSongs = (0..<5).map { makeDummySong(id: "L\($0)") }
        let service = MusicKitServiceImpl(client: client)

        let result = try await service.fetchPersonalRecommendations(history: [], limit: 20)

        #expect(result.count == 5)
        #expect(result.allSatisfy { $0.id.rawValue.hasPrefix("L") })
    }

    @Test("聴取実績があればレコメンドが返り、ライブラリは触らない")
    func recommendationPath() async throws {
        let client = MusicKitClientMock()
        client.artistSearchResult = [makeDummyArtist(id: "AR1", name: "DummyArtist")]
        client.artistTopSongs = (0..<20).map { makeDummySong(id: "T\($0)") }
        let history = (0..<10).map { makeDummySong(id: "H\($0 % 3)") }
        let service = MusicKitServiceImpl(client: client)

        let result = try await service.fetchPersonalRecommendations(history: history, limit: 20)

        #expect(!result.isEmpty)
        #expect(client.fetchPlaylistCalls.isEmpty)
    }
}
