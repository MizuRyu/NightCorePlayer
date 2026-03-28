import Testing
import Foundation
import MusicKit
@testable import Night_Core_Player

@Suite("ArtistDetailViewModel Tests", .serialized)
@MainActor
struct ArtistDetailViewModelTests {

    @Test("初期化: プロパティが初期値であること")
    func init_default_hasEmptyState() {
        // Given
        let svc = MusicKitServiceMock()
        let artist = makeDummyArtist()
        let vm = ArtistDetailViewModel(artist: artist, musicKitService: svc)

        // Then
        #expect(vm.songs.isEmpty, "songsが空であること")
        #expect(vm.errorMessage == nil, "errorMessageがnilであること")
        #expect(vm.isLoading == false, "isLoadingがfalseであること")
    }

    @Test("load: 成功時、楽曲が取得されエラーが nil になる")
    func load_success_updatesSongs() async {
        // Given
        let svc = MusicKitServiceMock()
        let songs = [makeDummySong(id: "A1"), makeDummySong(id: "A2")]
        svc.fetchArtistTopSongsResult = .success(songs)
        let artist = makeDummyArtist()
        let vm = ArtistDetailViewModel(artist: artist, musicKitService: svc)

        // When
        await vm.load()

        // Then
        #expect(vm.songs.count == 2, "2曲取得されること")
        #expect(vm.errorMessage == nil, "errorMessageがnilであること")
        #expect(vm.isLoading == false, "isLoadingがfalseであること")
    }

    @Test("load: 失敗時、エラーメッセージがセットされ songs が空になる")
    func load_failure_setsErrorMessage() async {
        // Given
        struct DummyErr: Error, LocalizedError {
            var errorDescription: String? { "test error" }
        }
        let svc = MusicKitServiceMock()
        svc.fetchArtistTopSongsResult = .failure(DummyErr())
        let artist = makeDummyArtist()
        let vm = ArtistDetailViewModel(artist: artist, musicKitService: svc)

        // When
        await vm.load()

        // Then
        #expect(vm.songs.isEmpty, "songsが空であること")
        #expect(vm.errorMessage != nil, "errorMessageが設定されていること")
        #expect(vm.isLoading == false, "isLoadingがfalseであること")
    }

    @Test("load: 重複呼び出し時、2回目は無視される")
    func load_concurrent_preventsReentrancy() async {
        // Given
        let svc = MusicKitServiceMock()
        svc.fetchArtistTopSongsResult = .success([makeDummySong(id: "A1")])
        let artist = makeDummyArtist()
        let vm = ArtistDetailViewModel(artist: artist, musicKitService: svc)

        // When
        async let first: () = vm.load()
        async let second: () = vm.load()
        _ = await (first, second)

        // Then
        #expect(svc.fetchArtistTopSongsCallCount == 1, "fetchArtistTopSongsが1回だけ呼ばれること")
    }

    @Test("load: 結果が空の場合、songs が空で errorMessage が nil であること")
    func load_emptyResult_hasEmptySongs() async {
        // Given
        let svc = MusicKitServiceMock()
        svc.fetchArtistTopSongsResult = .success([])
        let artist = makeDummyArtist()
        let vm = ArtistDetailViewModel(artist: artist, musicKitService: svc)

        // When
        await vm.load()

        // Then
        #expect(vm.songs.isEmpty, "songsが空であること")
        #expect(vm.errorMessage == nil, "errorMessageがnilであること")
        #expect(vm.isLoading == false, "isLoadingがfalseであること")
    }
}
