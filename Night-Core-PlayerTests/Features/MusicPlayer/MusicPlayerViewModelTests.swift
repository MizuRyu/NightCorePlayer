import Testing
import Combine
import SwiftUI
import MusicKit

@testable import Night_Core_Player

@Suite
@MainActor
struct MusicPlayerViewModelTests {
    static func setUp() -> (
        vm: MusicPlayerViewModel,
        svc: MusicPlayerServiceMock,
        cancel: AnyCancellable
    ) {
        let svc = MusicPlayerServiceMock()
        let vm  = MusicPlayerViewModel(service: svc)
        let cancel = svc.snapshotSubject.sink { _ in }
        return (vm, svc, cancel)
    }
    
    @Test("初期化: プロパティが初期値であること")
    func testInitialValues() {
        // Given: ViewModelを初期化する
        let (vm, _, cancel) = MusicPlayerViewModelTests.setUp()
        // When: 何も操作しない
        // Then: 各プロパティは初期値である
        #expect(vm.title      == "—",                             "タイトルの初期値")
        #expect(vm.artist     == "—",                             "アーティストの初期値")
        #expect(vm.currentTime == 0,                              "currentTimeの初期値")
        #expect(vm.duration    == 0,                              "durationの初期値")
        #expect(vm.rate        == Constants.MusicPlayer.defaultPlaybackRate, "rateの初期値")
        #expect(vm.isPlaying   == false,                          "isPlayingの初期値")
        cancel.cancel()
    }
    
    @Test("playPauseTrack: isPlaying=falseの時play()が呼ばれること")
    func testPlayPauseTrack_play() async {
        // Given: isPlaying=false状態のViewModel
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        // When: playPauseTrackを呼ぶ
        vm.playPauseTrack()
        try? await Task.sleep(nanoseconds: 50_000_000)
        // Then: play()が1回呼ばれ、pause()は呼ばれない
        #expect(svc.playCounted  == 1, "play()が１回呼ばれる")
        #expect(svc.pauseCounted == 0, "pause()は呼ばれない")
        cancel.cancel()
    }
    
    @Test("playPauseTrack: isPlaying=trueの時pause()が呼ばれること")
    func testPlayPauseTrack_pause() async {
        // Given: isPlaying=trueのスナップショットを送信したViewModel
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        svc.snapshotSubject.send(
            MusicPlayerSnapshot(
                title: "-", artist: "-",
                artwork: Image(systemName: "music.note"),
                currentTime: 0, duration: 0,
                rate: vm.rate, isPlaying: true
            )
        )
        try? await Task.sleep(nanoseconds: 50_000_000)
        // When: playPauseTrackを呼ぶ
        vm.playPauseTrack()
        try? await Task.sleep(nanoseconds: 50_000_000)
        // Then: pause()が1回呼ばれ、play()は呼ばれない
        #expect(svc.pauseCounted == 1, "pause()が１回呼ばれる")
        #expect(svc.playCounted  == 0, "play()は呼ばれない")
        cancel.cancel()
    }
    
    @Test("nextTrack: next()が呼ばれること")
    func testNextTrack() async {
        // Given: ViewModelを初期化
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        // When: nextTrackを呼ぶ
        vm.nextTrack()
        try? await Task.sleep(nanoseconds: 50_000_000)
        // Then: next()が1回呼ばれる
        #expect(svc.nextCounted == 1, "next()が１回呼ばれる")
        cancel.cancel()
    }
    
    @Test("previousTrack: previous()が呼ばれること")
    func testPreviousTrack() async {
        // Given: ViewModelを初期化
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        // When: previousTrackを呼ぶ
        vm.previousTrack()
        try? await Task.sleep(nanoseconds: 50_000_000)
        // Then: previous()が1回呼ばれる
        #expect(svc.previousCounted == 1, "previous()が１回呼ばれる")
        cancel.cancel()
    }
    
    @Test("rewind15: currentTime=10の時seek(0)が呼ばれること")
    func testRewind15_minBoundary() async {
        // Given: currentTime=10,duration=60のスナップショット
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        svc.snapshotSubject.send(
            MusicPlayerSnapshot(
                title: "", artist: "",
                artwork: Image(systemName: "music.note"),
                currentTime: 10, duration: 60,
                rate: vm.rate, isPlaying: false
            )
        )
        try? await Task.sleep(nanoseconds: 50_000_000)
        // When: rewind15を呼ぶ
        vm.rewind15()
        try? await Task.sleep(nanoseconds: 50_000_000)
        // Then: seek(0)が呼ばれる
        #expect(svc.seekArgs.last == 0, "seek(0)が呼ばれる")
        cancel.cancel()
    }
    
    @Test("rewind15: currentTime=30の時seek(15)が呼ばれること")
    func testRewind15_normal() async {
        // Given: currentTime=30,duration=60のスナップショット
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        svc.snapshotSubject.send(
            MusicPlayerSnapshot(
                title: "", artist: "",
                artwork: Image(systemName: "music.note"),
                currentTime: 30, duration: 60,
                rate: vm.rate, isPlaying: false
            )
        )
        try? await Task.sleep(nanoseconds: 50_000_000)
        // When: rewind15を呼ぶ
        vm.rewind15()
        try? await Task.sleep(nanoseconds: 50_000_000)
        // Then: seek(15)が呼ばれる
        #expect(svc.seekArgs.last == 15, "seek(15)が呼ばれる")
        cancel.cancel()
    }
    
    @Test("forward15: currentTime=50,duration=60の時seek(60)が呼ばれること")
    func testForward15_maxBoundary() async {
        // Given: currentTime=50,duration=60のスナップショット
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        svc.snapshotSubject.send(
            MusicPlayerSnapshot(
                title: "", artist: "",
                artwork: Image(systemName: "music.note"),
                currentTime: 50, duration: 60,
                rate: vm.rate, isPlaying: false
            )
        )
        try? await Task.sleep(nanoseconds: 50_000_000)
        // When: forward15を呼ぶ
        vm.forward15()
        try? await Task.sleep(nanoseconds: 50_000_000)
        // Then: seek(60)が呼ばれる
        #expect(svc.seekArgs.last == 60, "seek(60)が呼ばれる")
        cancel.cancel()
    }
    
    @Test("forward15: currentTime=20,duration=60の時seek(35)が呼ばれること")
    func testForward15_normal() async {
        // Given: currentTime=20,duration=60のスナップショット
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        svc.snapshotSubject.send(
            MusicPlayerSnapshot(
                title: "", artist: "",
                artwork: Image(systemName: "music.note"),
                currentTime: 20, duration: 60,
                rate: vm.rate, isPlaying: false
            )
        )
        try? await Task.sleep(nanoseconds: 50_000_000)
        // When: forward15を呼ぶ
        vm.forward15()
        try? await Task.sleep(nanoseconds: 50_000_000)
        // Then: seek(35)が呼ばれる
        #expect(svc.seekArgs.last == 35, "seek(35)が呼ばれる")
        cancel.cancel()
    }
    
    @Test("seek: 任意時間にseek(to:)が呼ばれること")
    func testSeek() async {
        // Given: ViewModelを初期化
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        // When: seek(to: 42)を呼ぶ
        vm.seek(to: 42)
        try? await Task.sleep(nanoseconds: 50_000_000)
        // Then: seek(42)が呼ばれる
        #expect(svc.seekArgs.last == 42, "seek(42)が呼ばれる")
        cancel.cancel()
    }
    
    @Test("setRate: 範囲外は補正してchangeRate()が呼ばれること")
    func testSetRate_outOfRange() async {
        // Given: ViewModelを初期化
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        // When: setRateを0.1（下限未満）で呼ぶ
        vm.setRate(to: 0.1)
        try? await Task.sleep(nanoseconds: 50_000_000)
        // Then: rateは最小値・changeRate(min)が呼ばれる
        #expect(vm.rate == Constants.MusicPlayer.minPlaybackRate, "rateは最小値に補正される")
        #expect(svc.rateArgs.last == Constants.MusicPlayer.minPlaybackRate, "changeRate(min)が呼ばれる")
        // When: setRateを3.0（上限超）で呼ぶ
        vm.setRate(to: 3.0)
        try? await Task.sleep(nanoseconds: 50_000_000)
        // Then: rateは最大値・changeRate(max)が呼ばれる
        #expect(vm.rate == Constants.MusicPlayer.maxPlaybackRate, "rateは最大値に補正される")
        #expect(svc.rateArgs.last == Constants.MusicPlayer.maxPlaybackRate, "changeRate(max)が呼ばれる")
        cancel.cancel()
    }
    
    @Test("setRate: 有効値ならchangeRate()が呼ばれること")
    func testSetRate_normal() async {
        // Given: ViewModelを初期化
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        // When: setRateを1.5で呼ぶ
        vm.setRate(to: 1.5)
        try? await Task.sleep(nanoseconds: 50_000_000)
        // Then: rateが1.5、changeRate(1.5)が呼ばれる
        #expect(vm.rate == 1.5, "rateが1.5にセットされる")
        #expect(svc.rateArgs.last == 1.5, "changeRate(1.5)が呼ばれる")
        cancel.cancel()
    }
    
    @Test("changeRate(by:): rate が増加され、service.changeRate() が呼ばれること")
    func testChangeRateBy_normal() async {
        // Given: ViewModelの初期rateを取得
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        let base = vm.rate
        // When: changeRate(by: 0.2)を呼ぶ
        vm.changeRate(by: 0.2)
        try? await Task.sleep(nanoseconds: 50_000_000)
        // Then: rateが+0.2され、service.changeRateも呼ばれる
        #expect(vm.rate == base + 0.2, "rate が +0.2 されること")
        #expect(svc.rateArgs.last == base + 0.2, "service.changeRate(\(base + 0.2)) が呼ばれること")
        cancel.cancel()
    }
    
    @Test("changeRate(by:): rate 増加が上限を超えると最大値にクランプされること")
    func testChangeRateBy_clampUpper() async {
        // Given: ViewModelを初期化
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        // When: changeRate(by: 上限を超える値)を呼ぶ
        vm.changeRate(by: Constants.MusicPlayer.maxPlaybackRate * 2)
        try? await Task.sleep(nanoseconds: 50_000_000)
        // Then: rateが最大値、service.changeRateも最大値で呼ばれる
        #expect(vm.rate == Constants.MusicPlayer.maxPlaybackRate, "rate が最大値にクランプされること")
        #expect(svc.rateArgs.last == Constants.MusicPlayer.maxPlaybackRate, "service.changeRate(max) が呼ばれること")
        cancel.cancel()
    }
    
    @Test("loadPlaylist: autoPlay=falseならplay()されないこと")
    func testLoadPlaylist_setQueue() async {
        // Given: 3曲配列を用意
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        let songs: [Song] = [
            makeDummySong(id: "1"),
            makeDummySong(id: "2"),
            makeDummySong(id: "3")
        ]
        // When: loadPlaylist(autoPlay: false)を呼ぶ
        vm.loadPlaylist(songs: songs, startAt: 1, autoPlay: false)
        try? await Task.sleep(nanoseconds: 50_000_000)
        // Then: setQueueは呼ばれるがplay()は呼ばれない
        #expect(svc.setQueueArgs.count == 1, "setQueueが呼ばれる")
        #expect(svc.playCounted     == 0, "play()は呼ばれない")
        cancel.cancel()
    }
    
    @Test("loadPlaylist: autoPlay=trueでplay()が呼ばれること")
    func testLoadPlaylist_autoPlay() async {
        // Given: 3曲配列を用意
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        let songs: [Song] = [
            makeDummySong(id: "1"),
            makeDummySong(id: "2"),
            makeDummySong(id: "3")
        ]
        // When: loadPlaylist(autoPlay: true)を呼ぶ
        vm.loadPlaylist(songs: songs, startAt: 0, autoPlay: true)
        try? await Task.sleep(nanoseconds: 50_000_000)
        // Then: play()が1回呼ばれる
        #expect(svc.playCounted == 1, "play()が呼ばれる")
        cancel.cancel()
    }
    
    @Test("setQueue: 指定された楽曲が選択された場合、当該楽曲を再生すること")
    func testSetQueueUpdatesQueueAndIndex() async {
        // Given: 3曲配列を用意
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        let songs = [ makeDummySong(id: "A"), makeDummySong(id: "B"), makeDummySong(id: "C") ]
        // When: setQueueをstartAt:2で呼ぶ
        vm.setQueue(songs, startAt: 2)
        // service.setQueue -> mock は snapshotSubject.send(.empty) する
        try? await Task.sleep(nanoseconds: 50_000_000)
        // Then: musicPlayerQueueとcurrentIndexが正しく設定される
        #expect(vm.musicPlayerQueue == songs, "musicPlayerQueue が setQueue の内容になること")
        #expect(vm.currentIndex     == 2,     "currentIndex が startAt=2 になること")
        cancel.cancel()
    }

    @Test("moveQueueItem: service.moveItem(from:to:) が呼ばれること")
    func testMoveQueueItem() async {
        // Given
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        // currentIndex が 0、queue に最低 4 曲入っている前提
        
        // When (ローカル offset = 1 を newLocalIndex = 2 に移動)
        vm.moveQueueItem(IndexSet(integer: 1), to: 2)
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        // Then
        // ローカル src = 1 → global src = currentIndex(0) + 1 + 1 = 2
        // newLocalIndex(2) > src(1) → localDst = 2 - 1 = 1 → global dst = 0 + 1 + 1 = 2
        #expect(svc.moveArgs.contains(where: { $0 == (2, 2) }),
                "moveItem(from:2, to:2) が呼ばれること")
        cancel.cancel()
    }
    
    @Test("removeQueueItem: service.removeItem(at:) が呼ばれること")
    func testRemoveQueueItem() async {
        // Given
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        // currentIndex が 0、queue に最低 4 曲入っている前提
        
        // When (ローカル offset = 2 を削除)
        vm.removeQueueItem(at: IndexSet(integer: 2))
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        // Then
        // global idx = currentIndex(0) + 1 + 2 = 3
        #expect(svc.removeArgs.last == 3,
                "removeItem(at:3) が呼ばれること")
        cancel.cancel()
    }
    
    @Test("removeQueueItem (batch): 複数のオフセットから降順で service.removeItem(at:) が呼ばれること")
    func testRemoveQueueItemsBatch() async {
        // Given
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        // currentIndex が 0、queue に最低 5 曲入っている前提
        
        // When (ローカル offsets [1,3,2] → global [2,4,3] → 降順 [4,3,2])
        vm.removeQueueItem(at: IndexSet([1, 3, 2]))
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        // Then
        #expect(svc.removeArgs == [4, 3, 2],
                "removeArgs が降順 [4,3,2] で呼ばれること")
        cancel.cancel()
    }

    @Test("playNow: 実行後に単一曲キューとなり currentIndex==0 になること")
    func testPlayNowUpdatesQueueAndIndex() async {
        // Given: キューにAをセット、currentIndex=0
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        let A = makeDummySong(id: "A")
        vm.setQueue([A], startAt: 0)
        try? await Task.sleep(nanoseconds: 50_000_000)
        // When: playNow(B)を呼ぶ
        let B = makeDummySong(id: "B")
        vm.playNow(B)
        try? await Task.sleep(nanoseconds: 50_000_000)
        // Then: musicPlayerQueueが[B]になりcurrentIndex==0
        #expect(vm.musicPlayerQueue == [B], "playNow 後にキューが [B] のみになること")
        #expect(vm.currentIndex     == 0,   "currentIndex が0になること")
        cancel.cancel()
    }
    
    @Test("playNowNext: playNextAndPlay() が呼び出されること")
    func testPlayNowNextCallsService() async {
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        let song = makeDummySong(id: "X")
        
        // When
        vm.playNowNext(song)
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        // Then
        #expect(svc.playNextAndPlayArgs == [song],
                "playNextAndPlay(_:) が１回だけ呼ばれること")
        cancel.cancel()
    }
    
    @Test("playNowNext: サービスの状態を VM に反映すること")
    func testPlayNowNextUpdatesQueueAndIndex() async {
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        let song = makeDummySong(id: "Y")
        // Given: モックサービスが返すキューとインデックス
        svc.musicPlayerQueue = [makeDummySong(id: "A"), song, makeDummySong(id: "B")]
        svc.nowPlayingIndex  = 1
        
        // When
        vm.playNowNext(song)
        try? await Task.sleep(nanoseconds: 50_000_000)
        // Then: ViewModel のキューとインデックスがサービスと一致
        #expect(vm.musicPlayerQueue == svc.musicPlayerQueue,
                "VM.musicPlayerQueue がサービスのキューと一致すること")
        #expect(vm.currentIndex == svc.nowPlayingIndex,
                "VM.currentIndex がサービスのインデックスと一致すること")
        cancel.cancel()
    }
    
    @Test("insertNext: 次の曲に割り込みで追加されること")
    func testInsertNextUpdatesQueueAndIndex() async {
        // Given: キューに[A, B]、currentIndex=0
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        let songs = [ makeDummySong(id: "A"), makeDummySong(id: "B") ]
        vm.setQueue(songs, startAt: 0)
        try? await Task.sleep(nanoseconds: 50_000_000)
        // When: insertNext(X)を呼ぶ
        let X = makeDummySong(id: "X")
        vm.insertNext(X)
        // ViewModel の insertNext は service.insertNext -> すぐに queue/index 同期
        try? await Task.sleep(nanoseconds: 50_000_000)
        // Then: [A, X, B] になりcurrentIndex==0
        #expect(vm.musicPlayerQueue == [makeDummySong(id: "A"), X, makeDummySong(id: "B")],
                "insertNext 後に X が2番目に挿入されること")
        #expect(vm.currentIndex == 0, "現在再生中の楽曲（currentIndex） は元のまま0のこと")
        cancel.cancel()
    }
    
    @Test("clearHistory: 実行後に history が空になること")
    func testClearHistory() async {
        // Given: serviceのplayHistoryに要素を入れる
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        svc.playHistory = [ makeDummySong(id: "A") ]
        svc.snapshotSubject.send(.empty)
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(vm.history.isEmpty == false, "事前に history に要素があること")
        // When: clearHistoryを呼ぶ
        vm.clearHistory()
        svc.snapshotSubject.send(.empty)
        try? await Task.sleep(nanoseconds: 50_000_000)
        // Then: historyが空になる
        #expect(vm.history.isEmpty, "clearHistory 後に history が空になること")
        cancel.cancel()
    }
    
    @Test("snapshot受信: プロパティが更新されること")
    func testSnapshotUpdate() async {
        // Given: MusicPlayerSnapshotを生成
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        let snap = MusicPlayerSnapshot(
            title: "テスト曲",
            artist: "アーティスト",
            artwork: Image(systemName: "star"),
            currentTime: 20,
            duration: 120,
            rate: 1.2,
            isPlaying: true
        )
        // When: snapshotSubjectにsnapを送信
        svc.snapshotSubject.send(snap)
        try? await Task.sleep(nanoseconds: 50_000_000)
        // Then: ViewModelのプロパティが更新される
        #expect(vm.title       == "テスト曲",               "タイトル更新")
        #expect(vm.artist      == "アーティスト",           "アーティスト更新")
        #expect(vm.currentTime == 20,                       "currentTime更新")
        #expect(vm.duration    == 120,                      "duration更新")
        #expect(vm.rate        == 1.2,                      "rate更新")
        #expect(vm.isPlaying   == true,                     "isPlaying更新")
        cancel.cancel()
    }
    
    @Test("formatRemainingTime: 現在トラックのみ、rate=1.0 のとき正しく計算されること")
    func testFormatRemainingTime_onlyCurrent() {
        // 残り = 90 - 30 = 60 秒 → rate=1 で 60 秒 → "01:00"
        let result = MusicPlayerViewModel.formatRemainingTime(
            currentTime: 30,
            duration: 90,
            upcomingDurations: 0,
            rate: 1.0
        )
        #expect(result == "01:00", "残り60秒が “01:00” になる")
    }
    
    @Test("formatRemainingTime: 今後のトラックも含め、rate=2.0 のとき正しく計算されること")
    func testFormatRemainingTime_withUpcomingAndRate() {
        // 現在残り = 70 - 10 = 60 秒、今後 120 秒 → 合計 180 秒
        // rate=2 で 90 秒 → "01:30"
        let result = MusicPlayerViewModel.formatRemainingTime(
            currentTime: 10,
            duration: 70,
            upcomingDurations: 120,
            rate: 2.0
        )
        #expect(result == "01:30", "180 秒 / rate 2 = 90 秒 が “01:30” になる")
    }
    
    @Test("formatRemainingTime: rate=0 のときゼロ除算せずに安全に動くこと")
    func testFormatRemainingTime_zeroRate() {
        // (50 - 10) + 30 = 70 秒 → rate がクリップされて 70 秒 → "01:10"
        let result = MusicPlayerViewModel.formatRemainingTime(
            currentTime: 10,
            duration: 50,
            upcomingDurations: 30,
            rate: 0.0
        )
        #expect(result == "01:10", "rate=0 でも “01:10” になる")
    }
    
    @Test("remainingTimeString: ServiceSnapshot を受け取ったあと ViewModel.remainingTimeString が正しく更新されること")
    func testRemainingTimeString_afterSnapshot() async {
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        // モックサービスにキューとインデックスをセット
        let songs = [
            makeDummySong(id: "A", duration: 60),
            makeDummySong(id: "B", duration: 120)
        ]
        svc.musicPlayerQueue = songs
        svc.nowPlayingIndex = 0
        
        // スナップショット送信: currentTime=30, duration=60, rate=1.5
        svc.snapshotSubject.send(
            MusicPlayerSnapshot(
                title: "", artist: "",
                artwork: Image(systemName: "music.note"),
                currentTime: 30,
                duration: 60,
                rate: 1.5,
                isPlaying: false
            )
        )
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        // 残り = (60-30) + 120 = 150 秒 → rate=1.5 で 100 秒 → "01:40"
        #expect(vm.remainingTimeString == "01:40", "remainingTimeString が “01:40” になる")
        cancel.cancel()
    }
}
