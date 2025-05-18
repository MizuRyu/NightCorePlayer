import Testing
import Foundation
import MusicKit
@testable import Night_Core_Player

@Suite
@MainActor
struct PlaylistDetailViewModelTests {
    // ポイント1: テストごとの共通セットアップ
    static func setUp() -> (
        viewModel: PlaylistDetailViewModel,
        serviceMock: MusicKitServiceMock_Playlist
    ) {
        let playlist = makeDummyPlaylist(id: "test", name: "testTitle")
        let serviceMock = MusicKitServiceMock_Playlist()
        let viewModel = PlaylistDetailViewModel(
            playlist: playlist,
            musicKitService: serviceMock
        )
        return (viewModel, serviceMock)
    }
    
    @Test("load: 成功時、songsに取得した曲が設定され、errorMessageがnilであること")
    func loadSuccess() async {
        // Given:
        let (viewModel, serviceMock) = PlaylistDetailViewModelTests.setUp()
        let expectedSongs = [
            makeDummySong(id: "1", title: "A"),
            makeDummySong(id: "2", title: "B"),
        ]
        serviceMock.result = .success(expectedSongs)
        
        // When
        await viewModel.load()
        
        // Then
        #expect(serviceMock.fetchPlaylistSongsCallCount == 1, "fetchPlaylistSongsが呼ばれていること")
        #expect(viewModel.songs == expectedSongs, "取得した曲がsongsに設定されること")
        #expect(viewModel.errorMessage == nil, "errorMessageがnilであること")
        #expect(viewModel.isLoading == false, "isLoadingがfalseに戻っていること")
    }
    
    @Test("load: 失敗時、songsが空でerrorMessageが設定されること")
    func loadFailure() async {
        // Given
        let (viewModel, serviceMock) = PlaylistDetailViewModelTests.setUp()
        let testError = NSError(domain: "Test", code: -1, userInfo: [NSLocalizedDescriptionKey: "失敗しました"])
        serviceMock.result = .failure(testError)
        
        // When
        await viewModel.load()
        
        // Then
        #expect(serviceMock.fetchPlaylistSongsCallCount == 1, "fetchPlaylistSongsが呼ばれていること")
        #expect(viewModel.songs.isEmpty, "songsが空配列であること")
        #expect(viewModel.errorMessage == "失敗しました", "errorMessageにエラーの説明が設定されること")
        #expect(viewModel.isLoading == false, "isLoadingがfalseに戻っていること")
    }
    
    @Test("load: 同時起動時、isLoadingがtrueのときは二重呼び出しを防止すること")
    func loadReentrancyPrevention() async {
        // Given
        let (viewModel, serviceMock) = PlaylistDetailViewModelTests.setUp()
        serviceMock.result = .success([])
        
        // When
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await viewModel.load() }
            group.addTask { await viewModel.load() }
        }
        
        // Then
        #expect(serviceMock.fetchPlaylistSongsCallCount == 1, "同時呼び出しでも一度しかfetchされないこと")
    }
}

