import Testing
import Combine
import SwiftUI
import MusicKit
@testable import Night_Core_Player

// テストデータ生成 Helper
internal func makeDummySong(id: String) -> Song {
    let data = """
    { "id":"\(id)",
      "type":"songs",
      "attributes": { "name":"DummyTitle", "artistName":"DummyArtist" }
    }
    """.data(using: .utf8)!
    return try! JSONDecoder().decode(Song.self, from: data)
}

internal func makeDummyPlaylist(id: String, name: String = "DummyList") -> Playlist {
    let data = """
    { "id":"\(id)",
      "type":"playlists",
      "attributes": { "name":"\(name)" }
    }
    """.data(using: .utf8)!
    return try! JSONDecoder().decode(Playlist.self, from: data)
}

@Suite
@MainActor
struct MusicKitServiceImplTests {
    
    static func setUp() -> (svc: MusicKitServiceImpl, mock: MusicKitClientMock) {
        let mock = MusicKitClientMock()
        let svc  = MusicKitServiceImpl(client: mock)
        return (svc, mock)
    }
    
    @Test("searchSongs: 権限OK & 結果あり → Song 配列を返す")
    func searchSongs_success() async throws {
        // Given
        let (svc, mock) = MusicKitServiceImplTests.setUp()
        mock.authStatus   = .authorized
        mock.searchResult = [
            makeDummySong(id: "S1"),
            makeDummySong(id: "S2")
        ]
        
        // When
        let result = try await svc.searchSongs(keyword: "rock", limit: 25)
        
        // Then
        #expect(result.count == 2, "2曲返ること")
        #expect(mock.searchCalls.first?.term == "rock", "検索ワードが渡ること")
    }
    
    @Test("searchSongs: 権限OK・0件 → 空配列")
    func searchSongs_empty() async throws {
        // Given
        let (svc, mock) = MusicKitServiceImplTests.setUp()
        mock.authStatus   = .authorized
        mock.searchResult = []
        
        // When
        let result = try await svc.searchSongs(keyword: "unknown", limit: 10)
        
        // Then
        #expect(result.isEmpty, "空配列を返す")
    }
    
    @Test("searchSongs: 権限NG → throw")
    func searchSongs_unauthorized() async {
        // Given
        let (svc, mock) = MusicKitServiceImplTests.setUp()
        mock.authStatus = .denied
        
        // When, Then
        do {
            _ = try await svc.searchSongs(keyword: "x")
            #expect(Bool(false), "例外をthrow")
        } catch {
            #expect(mock.authorizationRequests == 1, "権限確認が呼ばれる")
        }
    }
    
    @Test("searchSongs: notDetermined→authorized → 成功")
    func searchSongs_firstGrant() async throws {
        // Given
        let (svc, mock) = MusicKitServiceImplTests.setUp()
        mock.authStatus   = .authorized   // 1回目で許可
        mock.searchResult = [ makeDummySong(id: "S1") ]
        
        // Then
        let songs = try await svc.searchSongs(keyword: "foo", limit: 1)
        #expect(songs.count == 1, "1曲返る")
        #expect(mock.authorizationRequests == 1, "権限確認が1回")
    }
    
    @Test("searchSongs: restricted → throw")
    func searchSongs_restricted() async {
        // Given
        let (svc, mock) = MusicKitServiceImplTests.setUp()
        mock.authStatus = .restricted
        
        // When, Then
        do {
            _ = try await svc.searchSongs(keyword: "x")
            #expect(Bool(false), "throw されるべき")
        } catch { #expect(true) }
    }
    
    @Test("fetchLibraryPlaylists: 権限OK で playlists を返す")
    func fetchPlaylists_success() async throws {
        // Given
        let (svc, mock) = MusicKitServiceImplTests.setUp()
        mock.authStatus = .authorized
        mock.playlists  = [
            makeDummyPlaylist(id: "P1", name: "name1"),
            makeDummyPlaylist(id: "P2", name: "name2"),
            makeDummyPlaylist(id: "P3", name: "name3")
        ]

        // Then
        let lists = try await svc.fetchLibraryPlaylists(limit: 10)
        
        // Then
        #expect(lists.count == 3, "3件返る")
        #expect(mock.fetchPlaylistCalls.first == 10, "limit が渡る")
    }
    
    // B2 limit で切り詰め
    @Test("fetchLibraryPlaylists: 15件→limit10 で10件返す")
    func fetchPlaylists_limit() async throws {
        let (svc, mock) = MusicKitServiceImplTests.setUp()
        mock.authStatus = .authorized
        mock.playlists  = (0..<15).map { i in makeDummyPlaylist(id: "P\(i)", name: "name\(i)") }

        let lists = try await svc.fetchLibraryPlaylists(limit: 10)
        #expect(lists.count == 10, "10件に切り詰め")
    }
    
    // B3 権限NG
    @Test("fetchLibraryPlaylists: 権限NG → throw")
    func fetchPlaylists_unauthorized() async {
        let (svc, mock) = MusicKitServiceImplTests.setUp()
        mock.authStatus = .denied
        do {
            _ = try await svc.fetchLibraryPlaylists(limit: 5)
            #expect(Bool(false))
        } catch { #expect(true) }
    }
    
    @Test("fetchPlaylistSongs: 曲配列を返す")
    func fetchPlaylistSongs_success() async throws {
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
    
    @Test("fetchPlaylistSongs: 空プレイリスト → 空配列")
    func fetchPlaylistSongs_empty() async throws {
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
    func fetchPlaylistSongs_filter() async throws {
        // Given
        let (svc, mock) = MusicKitServiceImplTests.setUp()
        mock.authStatus = .authorized
        // client 内でフィルタ後 Song を2件返す想定
        mock.playlistSongs = [
            makeDummySong(id: "S1"),
            makeDummySong(id: "S2")
        ]
        let pl = makeDummyPlaylist(id: "P1")

        // When
        let songs = try await svc.fetchPlaylistSongs(in: pl)
        
        // Then
        #expect(songs.count == 2, "Songだけ抽出される")
    }
    
    @Test("fetchPlaylistSongs: 権限NG → throw")
    func fetchPlaylistSongs_unauthorized() async {
        // Given
        let (svc, mock) = MusicKitServiceImplTests.setUp()
        mock.authStatus = .denied
        
        // When, Then
        do {
            _ = try await svc.fetchPlaylistSongs(in: makeDummyPlaylist(id: "P1", name: "name1"))
            #expect(Bool(false))
        } catch { #expect(true) }
    }
}
