import Testing
import Combine
import SwiftUI
import MusicKit
@testable import Night_Core_Player

// MARK: - ViewModel Tests

@Suite
@MainActor
struct MusicPlayerViewModelTests {
    static func setUp() -> (
        vm: MusicPlayerViewModel,
        serviceMock: MusicPlayerServiceMock_ForViewModel,
        cancel: AnyCancellable
    ) {
        let serviceMock = MusicPlayerServiceMock_ForViewModel()
        let vm = MusicPlayerViewModel(service: serviceMock)
        // ViewModel が自身で snapshotPublisher を購読して内部プロパティを更新するため、
        // テスト側での購読は不要だがキャンセル用に返却する。
        let cancel = serviceMock.snapshotPublisher.sink { _ in }
        return (vm, serviceMock, cancel)
    }
    
    @Test("初期化: プロパティが初期値であること")
    func testInitialValues() {
        let (vm, _, cancel) = MusicPlayerViewModelTests.setUp()
        #expect(vm.title == "—", "タイトルの初期値が正しいこと")
        #expect(vm.artist == "—", "アーティストの初期値が正しいこと")
        #expect(vm.currentTime == 0, "currentTimeの初期値が正しいこと")
        #expect(vm.duration == 0, "durationの初期値が正しいこと")
        #expect(vm.rate == Constants.MusicPlayer.defaultPlaybackRate, "rateの初期値が正しいこと")
        #expect(vm.isPlaying == false, "isPlayingの初期値が正しいこと")
        cancel.cancel()
    }
    
    @Test("playPauseTrack: isPlaying=falseの時play()が呼ばれること")
    func testPlayPauseTrack_play() async {
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        
        vm.playPauseTrack()
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        #expect(svc.playCallCount == 1, "play()が呼ばれること")
        #expect(svc.pauseCallCount == 0, "pause()は呼ばれないこと")
        cancel.cancel()
    }
    
    @Test("playPauseTrack: isPlaying=trueの時pause()が呼ばれること")
    func testPlayPauseTrack_pause() async {
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        
        let playingSnap = MusicPlayerSnapshot(
            title: "-", artist: "-",
            artwork: Image(systemName: "music.note"),
            currentTime:0, duration: 0,
            rate: vm.rate, isPlaying: true
        )
        svc.snapshotSubject.send(playingSnap)
        
        vm.playPauseTrack()
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        #expect(svc.pauseCallCount == 1, "pause()が呼ばれること")
        #expect(svc.playCallCount == 0, "play()は呼ばれないこと")
        cancel.cancel()
    }
    
    @Test("nextTrack: next()が呼ばれること")
    func testNextTrack() async {
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        
        vm.nextTrack()
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        #expect(svc.nextCallCount == 1, "next()が呼ばれること")
        cancel.cancel()
    }
    
    @Test("previousTrack: previous()が呼ばれること")
    func testPreviousTrack() async {
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        
        vm.previousTrack()
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        #expect(svc.previousCallCount == 1, "previous()が呼ばれること")
        cancel.cancel()
    }
    
    @Test("rewind15: currentTime=10の時seek(0)が呼ばれること")
    func testRewind15_minBoundary() async {
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        // 初期の currentTime/duration は snapshot で流す
        svc.snapshotSubject.send(
            MusicPlayerSnapshot(
                title: "", artist: "",
                artwork: Image(systemName: "music.note"),
                currentTime: 10, duration: 60,
                rate: vm.rate, isPlaying: false
            )
        )
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        vm.rewind15()
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        #expect(svc.seekCallArgs.last == 0, "seek(0)が呼ばれること")
        cancel.cancel()
    }
    
    @Test("rewind15: currentTime=30の時seek(15)が呼ばれること")
    func testRewind15_normal() async {
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
        
        vm.rewind15()
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        #expect(svc.seekCallArgs.last == 15, "seek(15)が呼ばれること")
        cancel.cancel()
    }
    
    @Test("forward15: currentTime=50,duration=60の時seek(60)が呼ばれること")
    func testForward15_maxBoundary() async {
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
        
        vm.forward15()
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        #expect(svc.seekCallArgs.last == 60, "seek(60)が呼ばれること")
        cancel.cancel()
    }
    
    @Test("forward15: currentTime=20,duration=60の時seek(35)が呼ばれること")
    func testForward15_normal() async {
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
        
        vm.forward15()
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        #expect(svc.seekCallArgs.last == 35, "seek(35)が呼ばれること")
        cancel.cancel()
    }
    
    @Test("seek: 任意時間にseek(to:)が呼ばれること")
    func testSeek() async {
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        
        vm.seek(to: 42)
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        #expect(svc.seekCallArgs.last == 42, "seek(42)が呼ばれること")
        cancel.cancel()
    }
    
    @Test("setRate: 範囲外は補正してchangeRate()が呼ばれること")
    func testSetRate_outOfRange() async {
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        
        vm.setRate(to: 0.1)
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(vm.rate == Constants.MusicPlayer.minPlaybackRate, "rateが最小値に補正されること")
        #expect(svc.changeRateCallArgs.last == Constants.MusicPlayer.minPlaybackRate, "changeRate(min)が呼ばれること")
        
        vm.setRate(to: 3.0)
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(vm.rate == Constants.MusicPlayer.maxPlaybackRate, "rateが最大値に補正されること")
        #expect(svc.changeRateCallArgs.last == Constants.MusicPlayer.maxPlaybackRate, "changeRate(max)が呼ばれること")
        cancel.cancel()
    }
    
    @Test("setRate: 有効値ならchangeRate()が呼ばれること")
    func testSetRate_normal() async {
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        
        vm.setRate(to: 1.5)
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        #expect(vm.rate == 1.5, "rateが1.5にセットされること")
        #expect(svc.changeRateCallArgs.last == 1.5, "changeRate(1.5)が呼ばれること")
        cancel.cancel()
    }
    
    @Test("loadPlaylist: autoPlay=falseならplay()されないこと")
    func testLoadPlaylist_setQueue() async {
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        let songs: [Song] = [
            makeDummySong(id: "1"),
            makeDummySong(id: "2"),
            makeDummySong(id: "3")
        ]
        
        vm.loadPlaylist(songs: songs, startAt: 1, autoPlay: false)
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        #expect(svc.setQueueCallArgs.count == 1, "setQueueが呼ばれること")
        #expect(svc.playCallCount == 0, "play()は呼ばれないこと")
        cancel.cancel()
    }
    
    @Test("loadPlaylist: autoPlay=trueでplay()が呼ばれること")
    func testLoadPlaylist_autoPlay() async {
        let (vm, svc, cancel) = MusicPlayerViewModelTests.setUp()
        let songs: [Song] = [
            makeDummySong(id: "1"),
            makeDummySong(id: "2"),
            makeDummySong(id: "3")
        ]
        
        vm.loadPlaylist(songs: songs, startAt: 0, autoPlay: true)
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        #expect(svc.playCallCount == 1, "play()が呼ばれること")
        cancel.cancel()
    }
    
    @Test("snapshot受信: プロパティが更新されること")
    func testSnapshotUpdate() async {
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
        
        svc.snapshotSubject.send(snap)
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        #expect(vm.title == "テスト曲", "タイトルが更新されること")
        #expect(vm.artist == "アーティスト", "アーティストが更新されること")
        #expect(vm.currentTime == 20, "currentTimeが更新されること")
        #expect(vm.duration == 120, "durationが更新されること")
        #expect(vm.rate == 1.2, "rateが更新されること")
        #expect(vm.isPlaying == true, "isPlayingが更新されること")
        cancel.cancel()
    }
}
