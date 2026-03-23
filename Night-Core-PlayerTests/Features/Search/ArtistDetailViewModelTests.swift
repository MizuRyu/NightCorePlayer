import Testing
import Foundation
import MusicKit
@testable import Night_Core_Player

@Suite(.serialized)
@MainActor
struct ArtistDetailViewModelTests {

    @Test("load 成功: 楽曲が取得されエラーが nil になる")
    func load_success() async {
        // Given
        let svc = MusicKitServiceMock()
        let songs = [makeDummySong(id: "A1"), makeDummySong(id: "A2")]
        svc.fetchArtistTopSongsResult = .success(songs)
        let artist = makeDummyArtist()
        let vm = ArtistDetailViewModel(artist: artist, musicKitService: svc)

        // When
        await vm.load()

        // Then
        #expect(vm.songs.count == 2)
        #expect(vm.errorMessage == nil)
        #expect(vm.isLoading == false)
    }

    @Test("load 失敗: エラーメッセージがセットされ songs が空になる")
    func load_failure() async {
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
        #expect(vm.songs.isEmpty)
        #expect(vm.errorMessage != nil)
        #expect(vm.isLoading == false)
    }

    @Test("load 中の重複呼び出し: 2回目は無視される")
    func load_preventsDuplicate() async {
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
        #expect(svc.fetchArtistTopSongsCallCount == 1)
    }
}
