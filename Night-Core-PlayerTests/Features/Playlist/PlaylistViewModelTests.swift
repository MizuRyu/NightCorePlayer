import Testing
import SwiftUI
import MusicKit
@testable import Night_Core_Player


// MARK: - PlaylistViewModel Tests
@Suite("PlaylistViewModel Tests")
@MainActor
struct PlaylistViewModelTests {
    static func setUp() -> (
        viewModel: PlaylistViewModel,
        serviceMock: MusicKitServiceMock
    ) {
        let serviceMock = MusicKitServiceMock()
        let vm = PlaylistViewModel(musicKitService: serviceMock)
        return (vm, serviceMock)
    }

    @Test("初期化: プロパティが初期値であること")
    func init_default_hasEmptyState() {
        // Given
        let (vm, _) = PlaylistViewModelTests.setUp()

        // Then
        #expect(vm.rows.isEmpty, "rowsが空であること")
        #expect(vm.errorMessage == nil, "errorMessageがnilであること")
        #expect(vm.isLoading == false, "isLoadingがfalseであること")
    }

    @Test("load: プレイリスト取得成功時、rowsが更新され、errorMessageがnil、isLoadingはfalseであること")
    func load_success_updatesRows() async {
        // Given
        let playlists = [
            makeDummyPlaylist(id: "1", name: "P1"),
            makeDummyPlaylist(id: "2", name: "P2")
        ]
        let (vm, svc) = PlaylistViewModelTests.setUp()
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
    func load_failure_setsErrorMessage() async {
        // Given
        let (vm, svc) = PlaylistViewModelTests.setUp()
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
    func load_whileLoading_skipsServiceCall() async {
        // Given
        let (vm, svc) = PlaylistViewModelTests.setUp()
        vm.isLoading = true
        svc.fetchLibraryPlaylistsCallCount = 0

        // When
        await vm.load(limit: 1)

        // Then
        #expect(svc.fetchLibraryPlaylistsCallCount == 0, "fetchLibraryPlaylistsが呼ばれていないこと")
    }

    @Test("load: 結果が空の場合、rowsが空で errorMessage が nil であること")
    func load_emptyResult_hasEmptyRows() async {
        // Given
        let (vm, svc) = PlaylistViewModelTests.setUp()
        svc.fetchLibraryPlaylistsHandler = { _ in return [] }

        // When
        await vm.load(limit: 10)

        // Then
        #expect(vm.rows.isEmpty, "rowsが空であること")
        #expect(vm.errorMessage == nil, "errorMessageがnilであること")
        #expect(vm.isLoading == false, "isLoadingがfalseであること")
    }
}
