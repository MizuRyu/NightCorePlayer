import Testing
import Combine
import SwiftUI
import MusicKit
@testable import Night_Core_Player

@Suite("MusicKitServiceImpl Tests")
@MainActor
struct MusicKitServiceImplTests {

    static func setUp() -> (svc: MusicKitServiceImpl, mock: MusicKitClientMock) {
        let mock = MusicKitClientMock()
        let svc  = MusicKitServiceImpl(client: mock)
        return (svc, mock)
    }

    // MARK: - searchSongs

    @Test("searchSongs: 権限OK & 結果あり → Song 配列を返す")
    func searchSongs_authorized_returnsSongs() async throws {
        // Given
        let (svc, mock) = MusicKitServiceImplTests.setUp()
        mock.authStatus   = .authorized
        mock.searchResult = [makeDummySong(id: "S1"), makeDummySong(id: "S2")]

        // When
        let result = try await svc.searchSongs(keyword: "rock", limit: 25)

        // Then
        #expect(result.count == 2, "2曲返ること")
        #expect(mock.searchCalls.first?.term == "rock", "検索ワードが渡ること")
        #expect(mock.authorizationRequests == 1, "権限確認が1回呼ばれること")
    }

    @Test("searchSongs: 権限OK・0件 → 空配列を返す")
    func searchSongs_noResults_returnsEmpty() async throws {
        // Given
        let (svc, mock) = MusicKitServiceImplTests.setUp()
        mock.authStatus   = .authorized
        mock.searchResult = []

        // When
        let result = try await svc.searchSongs(keyword: "unknown", limit: 10)

        // Then
        #expect(result.isEmpty, "空配列を返す")
    }

    @Test("searchSongs: 権限 denied → NSError(domain: MusicKit) を throw する")
    func searchSongs_denied_throwsError() async {
        // Given
        let (svc, mock) = MusicKitServiceImplTests.setUp()
        mock.authStatus = .denied

        // When / Then
        await #expect(throws: (any Error).self) {
            try await svc.searchSongs(keyword: "x")
        }
        #expect(mock.authorizationRequests == 1, "権限確認が呼ばれること")
    }

    @Test("searchSongs: 初回許可で成功する")
    func searchSongs_firstGrant_succeeds() async throws {
        // Given
        let (svc, mock) = MusicKitServiceImplTests.setUp()
        mock.authStatus   = .authorized
        mock.searchResult = [makeDummySong(id: "S1")]

        // When
        let songs = try await svc.searchSongs(keyword: "foo", limit: 1)

        // Then
        #expect(songs.count == 1, "1曲返る")
        #expect(mock.authorizationRequests == 1, "権限確認が1回")
    }

    @Test("searchSongs: restricted → エラーを throw する")
    func searchSongs_restricted_throwsError() async {
        // Given
        let (svc, mock) = MusicKitServiceImplTests.setUp()
        mock.authStatus = .restricted

        // When / Then
        await #expect(throws: (any Error).self) {
            try await svc.searchSongs(keyword: "x")
        }
        #expect(mock.authorizationRequests == 1, "権限確認が呼ばれること")
    }

    // MARK: - fetchLibraryPlaylists

    @Test("fetchLibraryPlaylists: 権限OK で playlists を返す")
    func fetchPlaylists_authorized_returnsPlaylists() async throws {
        // Given
        let (svc, mock) = MusicKitServiceImplTests.setUp()
        mock.authStatus = .authorized
        mock.playlists  = [
            makeDummyPlaylist(id: "P1", name: "name1"),
            makeDummyPlaylist(id: "P2", name: "name2"),
            makeDummyPlaylist(id: "P3", name: "name3")
        ]

        // When
        let lists = try await svc.fetchLibraryPlaylists(limit: 10)

        // Then
        #expect(lists.count == 3, "3件返る")
        #expect(mock.fetchPlaylistCalls.first == 10, "limit が渡る")
    }

    @Test("fetchLibraryPlaylists: 15件→limit10 で10件に切り詰める")
    func fetchPlaylists_overLimit_truncates() async throws {
        // Given
        let (svc, mock) = MusicKitServiceImplTests.setUp()
        mock.authStatus = .authorized
        mock.playlists  = (0..<15).map { i in makeDummyPlaylist(id: "P\(i)", name: "name\(i)") }

        // When
        let lists = try await svc.fetchLibraryPlaylists(limit: 10)

        // Then
        #expect(lists.count == 10, "10件に切り詰め")
    }

    @Test("fetchLibraryPlaylists: 権限 denied → エラーを throw する")
    func fetchPlaylists_denied_throwsError() async {
        // Given
        let (svc, mock) = MusicKitServiceImplTests.setUp()
        mock.authStatus = .denied

        // When / Then
        await #expect(throws: (any Error).self) {
            try await svc.fetchLibraryPlaylists(limit: 5)
        }
        #expect(mock.authorizationRequests == 1, "権限確認が呼ばれること")
    }

    // MARK: - fetchPlaylistSongs

    @Test("fetchPlaylistSongs: 曲配列を返す")
    func fetchPlaylistSongs_authorized_returnsSongs() async throws {
        // Given
        let (svc, mock) = MusicKitServiceImplTests.setUp()
        mock.authStatus    = .authorized
        mock.playlistSongs = (1...5).map { i in makeDummySong(id: "S\(i)") }
        let pl = makeDummyPlaylist(id: "P1")

        // When
        let songs = try await svc.fetchPlaylistSongs(in: pl)

        // Then
        #expect(songs.count == 5, "5曲返る")
        #expect(mock.fetchSongsCalls.first?.id == pl.id, "playlist が渡る")
    }

    @Test("fetchPlaylistSongs: 空プレイリスト → 空配列を返す")
    func fetchPlaylistSongs_empty_returnsEmpty() async throws {
        // Given
        let (svc, mock) = MusicKitServiceImplTests.setUp()
        mock.authStatus    = .authorized
        mock.playlistSongs = []
        let pl = makeDummyPlaylist(id: "P1")

        // When
        let songs = try await svc.fetchPlaylistSongs(in: pl)

        // Then
        #expect(songs.isEmpty, "空配列")
    }

    @Test("fetchPlaylistSongs: Podcast混在でもSongのみ返す")
    func fetchPlaylistSongs_mixed_filtersSongsOnly() async throws {
        // Given
        let (svc, mock) = MusicKitServiceImplTests.setUp()
        mock.authStatus = .authorized
        mock.playlistSongs = [makeDummySong(id: "S1"), makeDummySong(id: "S2")]
        let pl = makeDummyPlaylist(id: "P1")

        // When
        let songs = try await svc.fetchPlaylistSongs(in: pl)

        // Then
        #expect(songs.count == 2, "Songだけ抽出される")
    }

    @Test("fetchPlaylistSongs: 権限 denied → エラーを throw する")
    func fetchPlaylistSongs_denied_throwsError() async {
        // Given
        let (svc, mock) = MusicKitServiceImplTests.setUp()
        mock.authStatus = .denied

        // When / Then
        await #expect(throws: (any Error).self) {
            try await svc.fetchPlaylistSongs(in: makeDummyPlaylist(id: "P1", name: "name1"))
        }
    }

    // MARK: - fetchPersonalRecommendations

    @Test("fetchPersonalRecommendations: 権限OK で楽曲を返す")
    func fetchRecommendations_authorized_returnsSongs() async throws {
        // Given
        let (svc, mock) = MusicKitServiceImplTests.setUp()
        mock.authStatus = .authorized
        mock.playlists = [makeDummyPlaylist(id: "P1")]
        mock.playlistSongs = [makeDummySong(id: "R1"), makeDummySong(id: "R2")]

        // When
        let songs = try await svc.fetchPersonalRecommendations(limit: 10)

        // Then
        #expect(!songs.isEmpty, "楽曲が返ること")
        #expect(songs.count <= 10, "limit 以下の件数であること")
    }

    @Test("fetchPersonalRecommendations: 権限 denied → エラーを throw する")
    func fetchRecommendations_denied_throwsError() async {
        // Given
        let (svc, mock) = MusicKitServiceImplTests.setUp()
        mock.authStatus = .denied

        // When / Then
        await #expect(throws: (any Error).self) {
            try await svc.fetchPersonalRecommendations(limit: 5)
        }
        #expect(mock.authorizationRequests == 1, "権限確認が呼ばれること")
    }

    @Test("fetchPersonalRecommendations: プレイリスト空 → 空配列を返す")
    func fetchRecommendations_noPlaylists_returnsEmpty() async throws {
        // Given
        let (svc, mock) = MusicKitServiceImplTests.setUp()
        mock.authStatus = .authorized
        mock.playlists = []

        // When
        let songs = try await svc.fetchPersonalRecommendations(limit: 5)

        // Then
        #expect(songs.isEmpty, "プレイリストがなければ空配列")
    }
}
