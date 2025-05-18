import Testing
import Combine
import SwiftUI
import MusicKit
import MediaPlayer
@testable import Night_Core_Player  // 実際のモジュール名に置き換えてください

// MARK: - MusicPlayerService モック実装

final class MusicPlayerServiceMock: MusicPlayerService {
    private(set) var setQueueCallArgs: [(songs: [Song], startAt: Int)] = []
    private(set) var playCallCount = 0
    private(set) var pauseCallCount = 0
    private(set) var nextCallCount = 0
    private(set) var previousCallCount = 0
    private(set) var seekCallArgs: [TimeInterval] = []
    private(set) var changeRateCallArgs: [Double] = []
    let snapshotSubject = PassthroughSubject<MusicPlayerSnapshot, Never>()
    var snapshotPublisher: AnyPublisher<MusicPlayerSnapshot, Never> {
        snapshotSubject.eraseToAnyPublisher()
    }
    
    func setQueue(songs: [Song], startAt index: Int) async {
        setQueueCallArgs.append((songs, index))
        // Snapshot 発行
        snapshotSubject.send(
            .init(title: "-", artist: "-", artwork: Image(systemName: "music.note"),
                  currentTime: 0, duration: 0, rate: Constants.MusicPlayer.defaultPlaybackRate, isPlaying: false)
        )
    }
    func play() async {
        playCallCount += 1
        snapshotSubject.send(
            .init(title: "-", artist: "-", artwork: Image(systemName: "music.note"),
                  currentTime: 0, duration: 0, rate: Constants.MusicPlayer.defaultPlaybackRate, isPlaying: true)
        )
    }
    func pause() async {
        pauseCallCount += 1
        snapshotSubject.send(
            .init(title: "-", artist: "-", artwork: Image(systemName: "music.note"),
                  currentTime: 0, duration: 0, rate: Constants.MusicPlayer.defaultPlaybackRate, isPlaying: false)
        )
    }
    func next() async { nextCallCount += 1 }
    func previous() async { previousCallCount += 1 }
    func seek(to time: TimeInterval) async {
        seekCallArgs.append(time)
        snapshotSubject.send(
            .init(title: "-", artist: "-", artwork: Image(systemName: "music.note"),
                  currentTime: time, duration: 0, rate: Constants.MusicPlayer.defaultPlaybackRate, isPlaying: false)
        )
    }
    func changeRate(to newRate: Double) async {
        changeRateCallArgs.append(newRate)
        snapshotSubject.send(
            .init(title: "-", artist: "-", artwork: Image(systemName: "music.note"),
                  currentTime: 0, duration: 0, rate: newRate, isPlaying: false)
        )
    }
    func currentSong() async throws -> Song? { nil }
    func currentArtworkImage(width: CGFloat, height: CGFloat) async throws -> Image {
        Image(systemName: "music.note")
    }
}

final class MusicPlayerServiceMock_ForViewModel: MusicPlayerService {
   private(set) var playCallCount = 0
   private(set) var pauseCallCount = 0
   private(set) var nextCallCount = 0
   private(set) var previousCallCount = 0
   private(set) var seekCallArgs: [TimeInterval] = []
   private(set) var changeRateCallArgs: [Double] = []
   private(set) var setQueueCallArgs: [(songs: [Song], startAt: Int)] = []
   
   let snapshotSubject = PassthroughSubject<MusicPlayerSnapshot, Never>()
   var snapshotPublisher: AnyPublisher<MusicPlayerSnapshot, Never> {
       snapshotSubject.eraseToAnyPublisher()
   }
   
   func setQueue(songs: [Song], startAt index: Int) async {
       setQueueCallArgs.append((songs, index))
   }
   func play() async { playCallCount += 1 }
   func pause() async { pauseCallCount += 1 }
   func next() async { nextCallCount += 1 }
   func previous() async { previousCallCount += 1 }
   func seek(to time: TimeInterval) async { seekCallArgs.append(time) }
   func changeRate(to newRate: Double) async { changeRateCallArgs.append(newRate) }
   func currentSong() async throws -> Song? { nil }
   func currentArtworkImage(width: CGFloat, height: CGFloat) async throws -> Image {
       Image(systemName: "music.note")
   }
}

