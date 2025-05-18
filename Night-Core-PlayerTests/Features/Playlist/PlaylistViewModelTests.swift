import Testing
import SwiftUI
import MusicKit
@testable import Night_Core_Player


// MARK: - PlaylistViewModel BDD Tests
@Suite
@MainActor
struct PlaylistViewModelTests {
    static func setUp() -> (
        viewModel: PlaylistViewModel,
        serviceMock: MusicKitServiceMock_Playlist,
        cancel: Void
    ) {
        let serviceMock = MusicKitServiceMock_Playlist()
        let vm = PlaylistViewModel(musicKitService: serviceMock)
        // サービス呼び出しキャプチャなどあればセットアップ
        return (vm, serviceMock, ())
    }
    
    @Test("load: プレイリスト取得成功時、rowsが更新され、errorMessageがnil、isLoadingはfalseであること")
    func testLoadSuccess() async {
        // Given
        let playlists = [
            makeDummyPlaylist(id: "1", name: "P1"),
            makeDummyPlaylist(id: "2", name: "P2")
        ]
        var (vm, svc, _) = PlaylistViewModelTests.setUp()
        svc.fetchLibraryPlaylistsHandler = { limit in
            return playlists
        }
        
        // When
        await vm.load(limit: 10)
        
        // Then
        #expect(vm.rows.count == playlists.count, "rowsの要素数が\(playlists.count)件であること")
        #expect(vm.errorMessage == nil, "errorMessageがnilであること")
        #expect(vm.isLoading == false, "isLoadingがfalseであること")
    }
    
    @Test("load: サービスエラー時、errorMessageが設定され、rowsは空であること")
    func testLoadFailure() async {
        // Given
        var (vm, svc, _) = PlaylistViewModelTests.setUp()
        svc.fetchLibraryPlaylistsHandler = { limit in
            throw URLError(.badServerResponse)
        }
        
        // When
        await vm.load(limit: 5)
        
        // Then
        #expect(vm.rows.isEmpty, "rowsが空であること")
        #expect(vm.errorMessage != nil, "errorMessageが設定されていること")
        #expect(vm.isLoading == false, "isLoadingがfalseであること")
    }
    
    @Test("load: isLoading=trueの時はサービスを再度呼び出さないこと")
    func testLoadWhileLoading() async {
        // Given
        var (vm, svc, _) = PlaylistViewModelTests.setUp()
        vm.isLoading = true
        svc.fetchLibraryPlaylistsCallCount = 0
        
        // When
        await vm.load(limit: 1)
        
        // Then: サービス呼び出しが行われない
        #expect(svc.fetchLibraryPlaylistsCallCount == 0, "fetchLibraryPlaylistsが呼ばれていないこと")
    }
    
    // TODO: Artworkフェッチ、キャッシュ更新のテストを追加
}
