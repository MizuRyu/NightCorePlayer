import Testing
import Foundation
import MusicKit
@testable import Night_Core_Player

@Suite("PlaylistDetailViewModel Tests")
@MainActor
struct PlaylistDetailViewModelTests {

    static func setUp() -> (
        viewModel: PlaylistDetailViewModel,
        serviceMock: MusicKitServiceMock
    ) {
        let playlist = makeDummyPlaylist(id: "test", name: "testTitle")
        let serviceMock = MusicKitServiceMock()
        let viewModel = PlaylistDetailViewModel(
            playlist: playlist,
            musicKitService: serviceMock
        )
        return (viewModel, serviceMock)
    }

    @Test("初期化: プロパティが初期値であること")
    func init_default_hasEmptyState() {
        // Given
        let (vm, _) = PlaylistDetailViewModelTests.setUp()

        // Then
        #expect(vm.songs.isEmpty, "songsが空であること")
        #expect(vm.errorMessage == nil, "errorMessageがnilであること")
        #expect(vm.isLoading == false, "isLoadingがfalseであること")
    }

    @Test("load: 成功時、songsに取得した曲が設定され、errorMessageがnilであること")
    func load_success_updatesSongs() async {
        // Given
        let (viewModel, serviceMock) = PlaylistDetailViewModelTests.setUp()
        let expectedSongs = [
            makeDummySong(id: "1", title: "A"),
            makeDummySong(id: "2", title: "B"),
        ]
        serviceMock.fetchPlaylistSongsResult = .success(expectedSongs)

        // When
        await viewModel.load()

        // Then
        #expect(serviceMock.fetchPlaylistSongsCallCount == 1, "fetchPlaylistSongsが呼ばれていること")
        #expect(viewModel.songs == expectedSongs, "取得した曲がsongsに設定されること")
        #expect(viewModel.errorMessage == nil, "errorMessageがnilであること")
        #expect(viewModel.isLoading == false, "isLoadingがfalseに戻っていること")
    }

    @Test("load: 失敗時、songsが空でerrorMessageが設定されること")
    func load_failure_setsErrorMessage() async {
        // Given
        let (viewModel, serviceMock) = PlaylistDetailViewModelTests.setUp()
        let testError = NSError(domain: "Test", code: -1, userInfo: [NSLocalizedDescriptionKey: "失敗しました"])
        serviceMock.fetchPlaylistSongsResult = .failure(testError)

        // When
        await viewModel.load()

        // Then
        #expect(serviceMock.fetchPlaylistSongsCallCount == 1, "fetchPlaylistSongsが呼ばれていること")
        #expect(viewModel.songs.isEmpty, "songsが空配列であること")
        #expect(viewModel.errorMessage == "失敗しました", "errorMessageにエラーの説明が設定されること")
        #expect(viewModel.isLoading == false, "isLoadingがfalseに戻っていること")
    }

    @Test("load: 同時起動時、isLoadingがtrueのときは二重呼び出しを防止すること")
    func load_concurrent_preventsReentrancy() async {
        // Given
        let (viewModel, serviceMock) = PlaylistDetailViewModelTests.setUp()
        serviceMock.fetchPlaylistSongsResult = .success([])

        // When
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await viewModel.load() }
            group.addTask { await viewModel.load() }
        }

        // Then
        #expect(serviceMock.fetchPlaylistSongsCallCount == 1, "同時呼び出しでも一度しかfetchされないこと")
    }

    @Test("load: 結果が空の場合、songsが空で errorMessage が nil であること")
    func load_emptyResult_hasEmptySongs() async {
        // Given
        let (viewModel, serviceMock) = PlaylistDetailViewModelTests.setUp()
        serviceMock.fetchPlaylistSongsResult = .success([])

        // When
        await viewModel.load()

        // Then
        #expect(viewModel.songs.isEmpty, "songsが空であること")
        #expect(viewModel.errorMessage == nil, "errorMessageがnilであること")
        #expect(viewModel.isLoading == false, "isLoadingがfalseであること")
    }
}

