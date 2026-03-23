import Testing
import Combine
import SwiftUI
import MusicKit
@testable import Night_Core_Player

@Suite(.serialized)
@MainActor
struct SearchViewModelTests {
    
    /// 共通セットアップ
    static func setUp() -> (
        vm: SearchViewModel,
        svc: MusicKitServiceMock_Search
    ) {
        UserDefaults.standard.removeObject(forKey: "searchHistory")
        let svc = MusicKitServiceMock_Search()
        let vm  = SearchViewModel(musicKitService: svc)
        return (vm, svc)
    }
    
    @Test("初期化時: プロパティは全て初期値であること")
    func initialState() {
        // Given
        let (vm, _) = SearchViewModelTests.setUp()
        // Then
        #expect(vm.query == "", "query が空文字であること")
        #expect(vm.songs.isEmpty, "songs が空配列であること")
        #expect(vm.isLoading == false, "isLoading が false であること")
        #expect(vm.errorMessage == nil, "errorMessage が nil であること")
    }
    
    @Test("空白クエリ: searchSongs を呼ばず songs をクリアすること")
    func blankQuery() async {
        // Given
        let (vm, svc) = SearchViewModelTests.setUp()
        
        // When
        vm.query = "   "
        try? await Task.sleep(nanoseconds: UInt64(Constants.Timing.searchDebounce + 50) * 1_000_000)
        
        // Then
        #expect(svc.searchCallArgs.isEmpty, "searchSongs が呼ばれないこと")
        #expect(vm.songs.isEmpty, "songs が空配列であること")
    }
    
    @Test("検索成功: isLoading の変遷と songs 更新")
    func searchSuccess() async {
        // Given
        let (vm, svc) = SearchViewModelTests.setUp()
        svc.stubSongs = [makeDummySong(id: "S1")]
        
        // When
        vm.query = "  Rock  "
        try? await Task.sleep(nanoseconds: UInt64(Constants.Timing.searchDebounce + 50) * 1_000_000)
        
        // Then
        #expect(svc.searchCallArgs.count == 1, "searchSongs が1回呼ばれること")
        #expect(svc.searchCallArgs.first?.keyword == "Rock", "キーワードの前後空白が除去されていること")
        #expect(vm.isLoading == false, "完了後 isLoading が false であること")
        #expect(vm.songs.count == 1, "songs が更新されること")
    }
    
    @Test("同一クエリ重複入力: removeDuplicates で1回のみ呼ばれること")
    func duplicateQuery() async {
        // Given
        let (vm, svc) = SearchViewModelTests.setUp()
        svc.stubSongs = [makeDummySong(id: "S1")]
        
        // When
        vm.query = "Jazz"
        try? await Task.sleep(nanoseconds: UInt64(Constants.Timing.searchDebounce + 50) * 1_000_000)
        vm.query = "Jazz"
        try? await Task.sleep(nanoseconds: UInt64(Constants.Timing.searchDebounce + 50) * 1_000_000)
        
        // Then
        #expect(svc.searchCallArgs.count == 1, "同一クエリは1回のみ検索されること")
    }
    
    @Test("検索失敗: error が設定され songs が空になること")
    func searchError() async {
        // Given
        struct DummyErr: Error {}
        let (vm, svc) = SearchViewModelTests.setUp()
        svc.searchError = DummyErr()

        // When
        vm.query = "Error"
        try? await Task.sleep(nanoseconds: UInt64(Constants.Timing.searchDebounce + 50) * 1_000_000)

        // Then
        #expect(svc.searchCallArgs.count == 1, "searchSongs が呼ばれること")
        #expect(vm.errorMessage != nil, "errorMessage がセットされること")
        #expect(vm.songs.isEmpty, "songs がクリアされること")
        #expect(vm.isLoading == false, "完了後 isLoading が false であること")
    }

    @Test("検索成功時: アーティストも取得される")
    func searchIncludesArtists() async {
        // Given
        let (vm, svc) = SearchViewModelTests.setUp()
        svc.stubSongs = [makeDummySong(id: "S1")]

        // When
        vm.query = "Artist"
        try? await Task.sleep(nanoseconds: UInt64(Constants.Timing.searchDebounce + 50) * 1_000_000)

        // Then
        #expect(svc.searchArtistsCallArgs.count == 1)
        #expect(svc.searchArtistsCallArgs.first?.keyword == "Artist")
    }

    @Test("キャンセルエラー: errorMessage に表示されない")
    func cancellationError_notShown() async {
        // Given
        let (vm, svc) = SearchViewModelTests.setUp()
        svc.stubSongs = [makeDummySong(id: "S1")]

        // When: 素早く連続で query を変更（前のタスクがキャンセルされる）
        vm.query = "First"
        vm.query = "Second"
        try? await Task.sleep(nanoseconds: UInt64(Constants.Timing.searchDebounce + 100) * 1_000_000)

        // Then: キャンセルエラーは表示されない
        #expect(vm.errorMessage == nil)
    }

    @Test("無限スクロール: hasMoreSongs が正しく設定される")
    func loadMore_hasMoreSongsFlag() async {
        // Given
        let (vm, svc) = SearchViewModelTests.setUp()
        let songs = (0..<25).map { makeDummySong(id: "S\($0)") }
        svc.stubSongs = songs

        // When
        await vm.performSearch(keyword: "Test")

        // Then: 25件 = limit なので追加あり
        #expect(vm.hasMoreSongs == true)
        #expect(vm.songs.count == 25)
    }

    @Test("無限スクロール: limit 未満の場合 hasMoreSongs が false")
    func loadMore_noMoreWhenUnderLimit() async {
        // Given
        let (vm, svc) = SearchViewModelTests.setUp()
        svc.stubSongs = [makeDummySong(id: "S1")]

        // When
        await vm.performSearch(keyword: "Test")

        // Then: 1件 < limit なので追加なし
        #expect(vm.hasMoreSongs == false)
    }

    @Test("無限スクロール: 最後以外の曲では発動しない")
    func loadMoreSongs_notTriggeredAtMiddleSong() async {
        // Given
        let (vm, svc) = SearchViewModelTests.setUp()
        let songs = (0..<25).map { makeDummySong(id: "S\($0)") }
        svc.stubSongs = songs

        // When
        await vm.performSearch(keyword: "Test")
        let initialCount = svc.searchCallArgs.count
        await vm.loadMoreSongsIfNeeded(currentSong: songs[10])

        // Then: 追加検索は発生しない
        #expect(svc.searchCallArgs.count == initialCount)
    }

    // MARK: - Search History Tests

    @Test("検索実行後: 履歴にキーワードが保存される")
    func history_savedAfterSearch() async {
        // Given
        let (vm, svc) = SearchViewModelTests.setUp()
        svc.stubSongs = [makeDummySong(id: "S1")]
        UserDefaults.standard.removeObject(forKey: "searchHistory")

        // When
        await vm.performSearch(keyword: "ONE OK ROCK")

        // Then
        #expect(vm.searchHistory.first == "ONE OK ROCK")
    }

    @Test("複数キーワード検索: 新しい順に履歴が並ぶ")
    func history_orderNewestFirst() async {
        // Given
        let (vm, svc) = SearchViewModelTests.setUp()
        svc.stubSongs = [makeDummySong(id: "S1")]
        UserDefaults.standard.removeObject(forKey: "searchHistory")

        // When
        await vm.performSearch(keyword: "Alpha")
        await vm.performSearch(keyword: "Beta")
        await vm.performSearch(keyword: "Gamma")

        // Then: 新しいものが先頭
        #expect(vm.searchHistory.first == "Gamma")
        #expect(vm.searchHistory.last == "Alpha")
        #expect(vm.searchHistory.count == 3)
    }

    @Test("上限20件: 超えた分は古いものから削除")
    func history_maxCount() async {
        // Given
        let (vm, svc) = SearchViewModelTests.setUp()
        svc.stubSongs = [makeDummySong(id: "S1")]
        UserDefaults.standard.removeObject(forKey: "searchHistory")

        // When
        for i in 0..<25 {
            await vm.performSearch(keyword: "keyword\(i)")
        }

        // Then
        #expect(vm.searchHistory.count == 20)
        #expect(vm.searchHistory.first == "keyword24")
    }

    @Test("個別削除: 指定インデックスの履歴が削除される")
    func history_removeItem() async {
        // Given
        let (vm, svc) = SearchViewModelTests.setUp()
        svc.stubSongs = [makeDummySong(id: "S1")]
        UserDefaults.standard.removeObject(forKey: "searchHistory")
        await vm.performSearch(keyword: "AAA")
        await vm.performSearch(keyword: "BBB")
        let countBefore = vm.searchHistory.count

        // When
        vm.removeHistoryItem(at: 0)

        // Then
        #expect(vm.searchHistory.count == countBefore - 1)
    }

    @Test("全削除: 履歴が空になる")
    func history_clearAll() async {
        // Given
        let (vm, svc) = SearchViewModelTests.setUp()
        svc.stubSongs = [makeDummySong(id: "S1")]
        UserDefaults.standard.removeObject(forKey: "searchHistory")
        await vm.performSearch(keyword: "AAA")

        // When
        vm.clearSearchHistory()

        // Then
        #expect(vm.searchHistory.isEmpty)
    }

    @Test("履歴タップ: query にキーワードがセットされる")
    func history_selectItem() {
        // Given
        let (vm, _) = SearchViewModelTests.setUp()

        // When
        vm.selectHistoryItem("YOASOBI")

        // Then
        #expect(vm.query == "YOASOBI")
    }
}
