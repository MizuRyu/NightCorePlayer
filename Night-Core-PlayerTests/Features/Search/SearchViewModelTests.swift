import Testing
import Combine
import SwiftUI
import MusicKit
@testable import Night_Core_Player

@Suite
@MainActor
struct SearchViewModelTests {
    
    /// 共通セットアップ
    static func setUp() -> (
        vm: SearchViewModel,
        svc: MusicKitServiceMock_Search
    ) {
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
        #expect(vm.error == nil, "error が nil であること")
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
        svc.stubError = DummyErr()
        
        // When
        vm.query = "Error"
        try? await Task.sleep(nanoseconds: UInt64(Constants.Timing.searchDebounce + 50) * 1_000_000)
        
        // Then
        #expect(svc.searchCallArgs.count == 1, "searchSongs が呼ばれること")
        #expect(vm.error != nil, "error がセットされること")
        #expect(vm.songs.isEmpty, "songs がクリアされること")
        #expect(vm.isLoading == false, "完了後 isLoading が false であること")
    }
}
