import Testing
import Combine
import SwiftUI
import MusicKit

@testable import Night_Core_Player

@Suite("MusicPlayerViewModel Tests", .serialized)
@MainActor
struct MusicPlayerViewModelTests {
    static func waitUntil(
        timeoutMilliseconds: Int = 1_000,
        pollMilliseconds: Int = 10,
        condition: @escaping @MainActor () -> Bool
    ) async {
        let attempts = max(1, timeoutMilliseconds / pollMilliseconds)
        for _ in 0..<attempts {
            if condition() {
                return
            }
            try? await Task.sleep(nanoseconds: UInt64(pollMilliseconds) * 1_000_000)
        }
    }

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
    func init_default_hasInitialValues() {
        // Given
        let (vm, _, cancel) = MusicPlayerViewModelTests.setUp()
        // Then
        #expect(vm.title      == "—",                             "タイトルの初期値")
        #expect(vm.artist     == "—",                             "アーティストの初期値")
        #expect(vm.currentTime == 0,                              "currentTimeの初期値")
        #expect(vm.duration    == 0,                              "durationの初期値")
        #expect(vm.rate        == Constants.MusicPlayer.defaultPlaybackRate, "rateの初期値")
        #expect(vm.isPlaying   == false,                          "isPlayingの初期値")
        cancel.cancel()
    }
    
    @Test("playPauseTrack: isPlaying=falseの時play()が呼ばれること")
    func playPauseTrack_notPlaying_callsPlay() async {
        // Given
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        // When
        vm.playPauseTrack()
        await MusicPlayerViewModelTests.waitUntil { svc.playCallCount == 1 }
        // Then
        #expect(svc.playCallCount  == 1, "play()が１回呼ばれる")
        #expect(svc.pauseCallCount == 0, "pause()は呼ばれない")
        cancel.cancel()
    }
    
    @Test("playPauseTrack: isPlaying=trueの時pause()が呼ばれること")
    func playPauseTrack_isPlaying_callsPause() async {
        // Given
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        svc.snapshotSubject.send(
            MusicPlayerSnapshot(
                title: "-", artist: "-",
                artworkData: nil,
                currentTime: 0, duration: 0,
                rate: vm.rate, isPlaying: true
            )
        )
        await MusicPlayerViewModelTests.waitUntil { vm.isPlaying == true }
        // When
        vm.playPauseTrack()
        await MusicPlayerViewModelTests.waitUntil { svc.pauseCallCount == 1 }
        // Then
        #expect(svc.pauseCallCount == 1, "pause()が１回呼ばれる")
        #expect(svc.playCallCount  == 0, "play()は呼ばれない")
        cancel.cancel()
    }
    
    @Test("nextTrack: next()が呼ばれること")
    func nextTrack_called_callsServiceNext() async {
        // Given
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        // When
        vm.nextTrack()
        await MusicPlayerViewModelTests.waitUntil { svc.nextCallCount == 1 }
        // Then
        #expect(svc.nextCallCount == 1, "next()が１回呼ばれる")
        cancel.cancel()
    }
    
    @Test("previousTrack: previous()が呼ばれること")
    func previousTrack_called_callsServicePrevious() async {
        // Given
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        // When
        vm.previousTrack()
        await MusicPlayerViewModelTests.waitUntil { svc.previousCallCount == 1 }
        // Then
        #expect(svc.previousCallCount == 1, "previous()が１回呼ばれる")
        cancel.cancel()
    }
    
    @Test("rewind15: currentTime=10の時seek(0)が呼ばれること")
    func rewind15_nearStart_seeksToZero() async {
        // Given
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        svc.snapshotSubject.send(
            MusicPlayerSnapshot(
                title: "", artist: "",
                artworkData: nil,
                currentTime: 10, duration: 60,
                rate: vm.rate, isPlaying: false
            )
        )
        await MusicPlayerViewModelTests.waitUntil { vm.currentTime == 10 }
        // When
        vm.rewind15()
        await MusicPlayerViewModelTests.waitUntil { svc.seekArgs.last == 0 }
        // Then
        #expect(svc.seekArgs.last == 0, "seek(0)が呼ばれる")
        cancel.cancel()
    }
    
    @Test("rewind15: currentTime=30の時seek(15)が呼ばれること")
    func rewind15_normal_seeksBack15() async {
        // Given
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        svc.snapshotSubject.send(
            MusicPlayerSnapshot(
                title: "", artist: "",
                artworkData: nil,
                currentTime: 30, duration: 60,
                rate: vm.rate, isPlaying: false
            )
        )
        await MusicPlayerViewModelTests.waitUntil { vm.currentTime == 30 }
        // When
        vm.rewind15()
        await MusicPlayerViewModelTests.waitUntil { svc.seekArgs.last == 15 }
        // Then
        #expect(svc.seekArgs.last == 15, "seek(15)が呼ばれる")
        cancel.cancel()
    }
    
    @Test("forward15: currentTime=50,duration=60の時seek(60)が呼ばれること")
    func forward15_nearEnd_seeksToEnd() async {
        // Given
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        svc.snapshotSubject.send(
            MusicPlayerSnapshot(
                title: "", artist: "",
                artworkData: nil,
                currentTime: 50, duration: 60,
                rate: vm.rate, isPlaying: false
            )
        )
        await MusicPlayerViewModelTests.waitUntil { vm.currentTime == 50 }
        // When
        vm.forward15()
        await MusicPlayerViewModelTests.waitUntil { svc.seekArgs.last == 60 }
        // Then
        #expect(svc.seekArgs.last == 60, "seek(60)が呼ばれる")
        cancel.cancel()
    }
    
    @Test("forward15: currentTime=20,duration=60の時seek(35)が呼ばれること")
    func forward15_normal_seeksForward15() async {
        // Given
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        svc.snapshotSubject.send(
            MusicPlayerSnapshot(
                title: "", artist: "",
                artworkData: nil,
                currentTime: 20, duration: 60,
                rate: vm.rate, isPlaying: false
            )
        )
        await MusicPlayerViewModelTests.waitUntil { vm.currentTime == 20 }
        // When
        vm.forward15()
        await MusicPlayerViewModelTests.waitUntil { svc.seekArgs.last == 35 }
        // Then
        #expect(svc.seekArgs.last == 35, "seek(35)が呼ばれる")
        cancel.cancel()
    }
    
    @Test("seek: 任意時間にseek(to:)が呼ばれること")
    func seek_anyTime_callsServiceSeek() async {
        // Given
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        // When
        vm.seek(to: 42)
        await MusicPlayerViewModelTests.waitUntil { svc.seekArgs.last == 42 }
        // Then
        #expect(svc.seekArgs.last == 42, "seek(42)が呼ばれる")
        cancel.cancel()
    }
    
    @Test("setRate: 範囲外は補正してsetSessionRate()が呼ばれること")
    func setRate_outOfRange_clampsToMinMax() async {
        // Given
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        // When: 下限未満
        vm.setRate(to: 0.1)
        await MusicPlayerViewModelTests.waitUntil {
            vm.rate == Constants.MusicPlayer.minPlaybackRate &&
            svc.rateArgs.last == Constants.MusicPlayer.minPlaybackRate
        }
        // Then
        #expect(vm.rate == Constants.MusicPlayer.minPlaybackRate, "rateは最小値に補正される")
        #expect(svc.rateArgs.last == Constants.MusicPlayer.minPlaybackRate, "setSessionRate(min)が呼ばれる")
        // When: 上限超
        vm.setRate(to: 3.0)
        await MusicPlayerViewModelTests.waitUntil {
            vm.rate == Constants.MusicPlayer.maxPlaybackRate &&
            svc.rateArgs.last == Constants.MusicPlayer.maxPlaybackRate
        }
        // Then
        #expect(vm.rate == Constants.MusicPlayer.maxPlaybackRate, "rateは最大値に補正される")
        #expect(svc.rateArgs.last == Constants.MusicPlayer.maxPlaybackRate, "setSessionRate(max)が呼ばれる")
        cancel.cancel()
    }
    
    @Test("setRate: 有効値ならsetSessionRate()が呼ばれること")
    func setRate_validValue_setsRate() async {
        // Given
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        // When
        vm.setRate(to: 1.5)
        await MusicPlayerViewModelTests.waitUntil {
            vm.rate == 1.5 &&
            svc.rateArgs.last == 1.5
        }
        // Then
        #expect(vm.rate == 1.5, "rateが1.5にセットされる")
        #expect(svc.rateArgs.last == 1.5, "setSessionRate(1.5)が呼ばれる")
        cancel.cancel()
    }
    
    @Test("adjustRate(by:): rate が増加され、service.setSessionRate() が呼ばれること")
    func adjustRate_increment_updatesRateAndService() async {
        // Given
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        let base = vm.rate
        // When
        vm.adjustRate(by: 0.2)
        await MusicPlayerViewModelTests.waitUntil { svc.rateArgs.last == base + 0.2 }
        // Then
        #expect(vm.rate == base + 0.2, "rate が +0.2 されること")
        #expect(svc.rateArgs.last == base + 0.2, "service.setSessionRate(\(base + 0.2)) が呼ばれること")
        cancel.cancel()
    }
    
    @Test("adjustRate(by:): rate 増加が上限を超えると最大値にクランプされること")
    func adjustRate_exceedsMax_clampedToMax() async {
        // Given
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        // When
        vm.adjustRate(by: Constants.MusicPlayer.maxPlaybackRate * 2)
        await MusicPlayerViewModelTests.waitUntil {
            vm.rate == Constants.MusicPlayer.maxPlaybackRate &&
            svc.rateArgs.last == Constants.MusicPlayer.maxPlaybackRate
        }
        // Then
        #expect(vm.rate == Constants.MusicPlayer.maxPlaybackRate, "rate が最大値にクランプされること")
        #expect(svc.rateArgs.last == Constants.MusicPlayer.maxPlaybackRate, "service.setSessionRate(max) が呼ばれること")
        cancel.cancel()
    }
    
    @Test("loadPlaylist: autoPlay=falseならplay()されないこと")
    func loadPlaylist_autoPlayFalse_noPlay() async {
        // Given
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        let songs: [Song] = [
            makeDummySong(id: "1"),
            makeDummySong(id: "2"),
            makeDummySong(id: "3")
        ]
        // When
        vm.loadPlaylist(songs: songs, startAt: 1, autoPlay: false)
        await MusicPlayerViewModelTests.waitUntil { svc.setQueueArgs.count == 1 }
        // Then
        #expect(svc.setQueueArgs.count == 1, "setQueueが呼ばれる")
        #expect(svc.playCallCount     == 0, "play()は呼ばれない")
        cancel.cancel()
    }
    
    @Test("loadPlaylist: autoPlay=trueでplay()が呼ばれること")
    func loadPlaylist_autoPlayTrue_callsPlay() async {
        // Given
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        let songs: [Song] = [
            makeDummySong(id: "1"),
            makeDummySong(id: "2"),
            makeDummySong(id: "3")
        ]
        // When
        vm.loadPlaylist(songs: songs, startAt: 0, autoPlay: true)
        await MusicPlayerViewModelTests.waitUntil { svc.playCallCount == 1 }
        // Then
        #expect(svc.playCallCount == 1, "play()が呼ばれる")
        cancel.cancel()
    }
    
    @Test("setQueue: 指定された楽曲が選択された場合、当該楽曲を再生すること")
    func setQueue_withStartAt_updatesQueueAndIndex() async {
        // Given
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        let songs = [ makeDummySong(id: "A"), makeDummySong(id: "B"), makeDummySong(id: "C") ]
        // When
        vm.setQueue(songs, startAt: 2)
        await MusicPlayerViewModelTests.waitUntil { vm.musicPlayerQueue == songs }
        // Then
        #expect(vm.musicPlayerQueue == songs, "musicPlayerQueue が setQueue の内容になること")
        #expect(vm.currentIndex     == 2,     "currentIndex が startAt=2 になること")
        cancel.cancel()
    }

    @Test("moveQueueItem: service.moveItem(from:to:) が呼ばれること")
    func moveQueueItem_validIndexes_callsServiceMove() async {
        // Given
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        // When
        vm.moveQueueItem(IndexSet(integer: 1), to: 2)
        await MusicPlayerViewModelTests.waitUntil { !svc.moveArgs.isEmpty }
        // Then
        #expect(svc.moveArgs.contains(where: { $0 == (2, 2) }),
                "moveItem(from:2, to:2) が呼ばれること")
        cancel.cancel()
    }
    
    @Test("removeQueueItem: service.removeItem(at:) が呼ばれること")
    func removeQueueItem_singleIndex_callsServiceRemove() async {
        // Given
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        // When
        vm.removeQueueItem(at: IndexSet(integer: 2))
        await MusicPlayerViewModelTests.waitUntil { svc.removeArgs.last == 3 }
        // Then
        #expect(svc.removeArgs.last == 3,
                "removeItem(at:3) が呼ばれること")
        cancel.cancel()
    }
    
    @Test("removeQueueItem (batch): 複数のオフセットから降順で service.removeItem(at:) が呼ばれること")
    func removeQueueItem_multipleIndexes_removesDescending() async {
        // Given
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        // When
        vm.removeQueueItem(at: IndexSet([1, 3, 2]))
        await MusicPlayerViewModelTests.waitUntil { svc.removeArgs.count == 3 }
        // Then
        #expect(svc.removeArgs == [4, 3, 2],
                "removeArgs が降順 [4,3,2] で呼ばれること")
        cancel.cancel()
    }

    @Test("playNow: 実行後に単一曲キューとなり currentIndex==0 になること")
    func playNow_singleSong_updatesQueue() async {
        // Given
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        let A = makeDummySong(id: "A")
        vm.setQueue([A], startAt: 0)
        await MusicPlayerViewModelTests.waitUntil { vm.musicPlayerQueue == [A] }
        // When
        let B = makeDummySong(id: "B")
        vm.playNow(B)
        await MusicPlayerViewModelTests.waitUntil { vm.musicPlayerQueue == [B] }
        // Then
        #expect(vm.musicPlayerQueue == [B], "playNow 後にキューが [B] のみになること")
        #expect(vm.currentIndex     == 0,   "currentIndex が0になること")
        cancel.cancel()
    }
    
    @Test("playNowNext: playNextAndPlay() が呼び出されること")
    func playNowNext_song_callsService() async {
        // Given
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        let song = makeDummySong(id: "X")
        // When
        vm.playNowNext(song)
        await MusicPlayerViewModelTests.waitUntil { svc.playNextAndPlayArgs.count == 1 }
        // Then
        #expect(svc.playNextAndPlayArgs == [song],
                "playNextAndPlay(_:) が１回だけ呼ばれること")
        cancel.cancel()
    }
    
    @Test("playNowNext: サービスの状態を VM に反映すること")
    func playNowNext_song_syncsQueueAndIndex() async {
        // Given
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        let song = makeDummySong(id: "Y")
        svc.musicPlayerQueue = [makeDummySong(id: "A"), song, makeDummySong(id: "B")]
        svc.nowPlayingIndex  = 1
        // When
        vm.playNowNext(song)
        await MusicPlayerViewModelTests.waitUntil { vm.musicPlayerQueue == svc.musicPlayerQueue }
        // Then
        #expect(vm.musicPlayerQueue == svc.musicPlayerQueue,
                "VM.musicPlayerQueue がサービスのキューと一致すること")
        #expect(vm.currentIndex == svc.nowPlayingIndex,
                "VM.currentIndex がサービスのインデックスと一致すること")
        cancel.cancel()
    }
    
    @Test("insertNext: 次の曲に割り込みで追加されること")
    func insertNext_song_insertsAfterCurrent() async {
        // Given
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        let songs = [ makeDummySong(id: "A"), makeDummySong(id: "B") ]
        vm.setQueue(songs, startAt: 0)
        await MusicPlayerViewModelTests.waitUntil { vm.musicPlayerQueue == songs }
        // When
        let X = makeDummySong(id: "X")
        vm.insertNext(X)
        let expected = [makeDummySong(id: "A"), X, makeDummySong(id: "B")]
        await MusicPlayerViewModelTests.waitUntil { vm.musicPlayerQueue == expected }
        // Then
        #expect(vm.musicPlayerQueue == expected,
                "insertNext 後に X が2番目に挿入されること")
        #expect(vm.currentIndex == 0, "現在再生中の楽曲（currentIndex） は元のまま0のこと")
        cancel.cancel()
    }
    
    @Test("clearHistory: 実行後に history が空になること")
    func clearHistory_withHistory_clearsAll() async {
        // Given
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        svc.playHistory = [ makeDummySong(id: "A") ]
        svc.snapshotSubject.send(.empty)
        await MusicPlayerViewModelTests.waitUntil { !vm.history.isEmpty }
        #expect(vm.history.isEmpty == false, "事前に history に要素があること")
        // When
        vm.clearHistory()
        svc.snapshotSubject.send(.empty)
        await MusicPlayerViewModelTests.waitUntil { vm.history.isEmpty }
        // Then
        #expect(vm.history.isEmpty, "clearHistory 後に history が空になること")
        cancel.cancel()
    }
    
    @Test("snapshot受信: プロパティが更新されること")
    func snapshotReceived_validSnapshot_updatesProperties() async {
        // Given
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        let snap = MusicPlayerSnapshot(
            title: "テスト曲",
            artist: "アーティスト",
            artworkData: nil,
            currentTime: 20,
            duration: 120,
            rate: 1.2,
            isPlaying: true
        )
        // When
        svc.snapshotSubject.send(snap)
        await MusicPlayerViewModelTests.waitUntil { vm.title == "テスト曲" }
        // Then
        #expect(vm.title       == "テスト曲",               "タイトル更新")
        #expect(vm.artist      == "アーティスト",           "アーティスト更新")
        #expect(vm.currentTime == 20,                       "currentTime更新")
        #expect(vm.duration    == 120,                      "duration更新")
        #expect(vm.rate        == 1.2,                      "rate更新")
        #expect(vm.isPlaying   == true,                     "isPlaying更新")
        cancel.cancel()
    }
    
    @Test("formatRemainingTime: 現在トラックのみ、rate=1.0 のとき正しく計算されること")
    func formatRemainingTime_onlyCurrent_formatsCorrectly() {
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
    func formatRemainingTime_withUpcomingAndRate_formatsCorrectly() {
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
    func formatRemainingTime_zeroRate_handlesSafely() {
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
    func remainingTimeString_afterSnapshot_calculatesCorrectly() async {
        // Given
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        let songs = [
            makeDummySong(id: "A", duration: 60),
            makeDummySong(id: "B", duration: 120)
        ]
        svc.musicPlayerQueue = songs
        svc.nowPlayingIndex = 0
        // When
        svc.snapshotSubject.send(
            MusicPlayerSnapshot(
                title: "", artist: "",
                artworkData: nil,
                currentTime: 30,
                duration: 60,
                rate: 1.5,
                isPlaying: false
            )
        )
        await MusicPlayerViewModelTests.waitUntil { vm.remainingTimeString == "01:40" }
        // Then
        #expect(vm.remainingTimeString == "01:40", "remainingTimeString が “01:40” になる")
        cancel.cancel()
    }

    // MARK: - Shuffle / Repeat / AutoPlay Tests

    @Test("toggleShuffle: toggleShuffle()がサービスに委譲されること")
    func toggleShuffle_called_togglesServiceShuffle() async {
        // Given
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        // When
        vm.toggleShuffle()
        await MusicPlayerViewModelTests.waitUntil { svc.isShuffled == true }
        // Then
        #expect(svc.isShuffled == true, "シャッフルが有効になる")
        cancel.cancel()
    }

    @Test("cycleRepeatMode: repeatModeがサイクルすること")
    func cycleRepeatMode_calledThreeTimes_cyclesThrough() async {
        // Given
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        #expect(svc.repeatMode == .none, "初期値は.none")
        // When / Then: none → all
        vm.cycleRepeatMode()
        await MusicPlayerViewModelTests.waitUntil { svc.repeatMode == .all }
        #expect(svc.repeatMode == .all, ".noneから.allに変わる")
        // When / Then: all → one
        vm.cycleRepeatMode()
        await MusicPlayerViewModelTests.waitUntil { svc.repeatMode == .one }
        #expect(svc.repeatMode == .one, ".allから.oneに変わる")
        // When / Then: one → none
        vm.cycleRepeatMode()
        await MusicPlayerViewModelTests.waitUntil { svc.repeatMode == .none }
        #expect(svc.repeatMode == .none, ".oneから.noneに変わる")
        cancel.cancel()
    }

    @Test("toggleAutoPlay: autoPlayがトグルされること")
    func toggleAutoPlay_calledTwice_togglesTwice() async {
        // Given
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        #expect(svc.isAutoPlayEnabled == false, "初期値はfalse")
        // When / Then: false → true
        vm.toggleAutoPlay()
        await MusicPlayerViewModelTests.waitUntil { svc.isAutoPlayEnabled == true }
        #expect(svc.isAutoPlayEnabled == true, "trueに変わる")
        // When / Then: true → false
        vm.toggleAutoPlay()
        await MusicPlayerViewModelTests.waitUntil { svc.isAutoPlayEnabled == false }
        #expect(svc.isAutoPlayEnabled == false, "falseに戻る")
        cancel.cancel()
    }

    @Test("bindService: shuffle/repeat/autoPlay状態がスナップショットで同期されること")
    func bindService_stateChanged_syncsShuffleRepeatAutoPlay() async {
        // Given
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        await svc.toggleShuffle()
        await svc.cycleRepeatMode()
        await svc.toggleAutoPlay()
        // When
        svc.snapshotSubject.send(.empty)
        await MusicPlayerViewModelTests.waitUntil { vm.isShuffled == true }
        // Then
        #expect(vm.isShuffled == true, "isShuffledが同期される")
        #expect(vm.repeatMode == .all, "repeatModeが同期される")
        #expect(vm.isAutoPlayEnabled == true, "isAutoPlayEnabledが同期される")
        cancel.cancel()
    }
}
