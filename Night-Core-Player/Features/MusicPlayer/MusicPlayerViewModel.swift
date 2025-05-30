import SwiftUI
import MusicKit
import MediaPlayer
import Combine

@MainActor
final class MusicPlayerViewModel: ObservableObject {
    @Published private(set) var musicPlayerQueue: [Song] = []
    @Published private(set) var currentIndex: Int = 0
    @Published private(set) var history: [Song] = []
    
    @Published private(set) var title: String      = "—"
    @Published private(set) var artist: String     = "—"
    @Published private(set) var artwork: Image     = Image(systemName: "music.note")
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double    = 0
    @Published private(set) var rate: Double        = Constants.MusicPlayer.defaultPlaybackRate
    @Published private(set) var isPlaying: Bool     = false

    private var skipSeconds: Double = Constants.MusicPlayer.skipSeconds

    // 次に再生される楽曲キュー配列
    var currentQueue: [Song] {
        Array(musicPlayerQueue.dropFirst(currentIndex + 1))
    }
    
    var remainingTimeString: String {
        Self.formatRemainingTime(
            currentTime: currentTime,
            duration: duration,
            upcomingDurations: upcomingTracksDuration,
            rate: rate
            )
    }
    
    // MARK: - Dependencies
    private let service: MusicPlayerService
    private var cancellables = Set<AnyCancellable>()
    
    init(service: MusicPlayerService) {
        self.service = service
        bindService()
    }
    
    func setQueue(_ songs: [Song], startAt idx: Int, autoPlay: Bool = true) {
        Task { await service.setQueue(songs: songs, startAt: idx, autoPlay: autoPlay) }
    }

    // 再生キューの操作をグローバルなqueueに反映する
    func moveQueueItem(_ offsets: IndexSet, to newLocalIndex: Int) {
        guard let localSrc = offsets.first else { return }
        let srcGlobal = currentIndex + 1 + localSrc

        let localDst = newLocalIndex > localSrc
            ? newLocalIndex - 1
            : newLocalIndex
        let dstGlobal = currentIndex + 1 + localDst
        Task {
            await service.moveItem(from: srcGlobal, to: dstGlobal)
        }
    }
    func removeQueueItem(at offsets: IndexSet) {
        Task {
            let absIndices = offsets.map { $0 + currentIndex + 1 }.sorted(by: >)
            for idx in absIndices {
                await service.removeItem(at: idx)
            }
        }
    }
    func playNow(_ song: Song) {
        Task {
            await service.playNow(song)
        }
    }
    // キューの先頭に楽曲を挿入し、再生を開始
    func playNowNext(_ song: Song) {
        Task {
            await service.playNextAndPlay(song)
        }
    }
    func insertNext(_ song: Song) {
        Task {
            await service.insertNext(song)
            self.musicPlayerQueue = service.musicPlayerQueue
            self.currentIndex = service.nowPlayingIndex
        }
    }
    func clearHistory() {
        service.clearHistory()
        self.history = []
    }
    
    
    func playPauseTrack()  { Task { await isPlaying ? service.pause() : service.play() } }
    func nextTrack()       { Task { await service.next()     } }
    func previousTrack()   { Task { await service.previous() } }
    func rewind15() {
        let newTime = max(currentTime - skipSeconds, 0)
        seek(to: newTime)
    }
    func forward15() {
        let newTime = min(currentTime + skipSeconds, duration)
        seek(to: newTime)
    }
    func seek(to time: Double){
        currentTime = time
        Task {
            await service.seek(to: time)
        }
    }
    func setRate(to newVal: Double) {
        let tmp = min(max(newVal,
                          Constants.MusicPlayer.minPlaybackRate),
                      Constants.MusicPlayer.maxPlaybackRate)
        rate = tmp
        Task { await service.changeRate(to: tmp) }
    }
    func changeRate(by delta: Double) {
        setRate(to: rate + delta)
    }
    
    func loadPlaylist(songs: [Song], startAt index: Int = 0, autoPlay: Bool = true) {
        Task {
            await service.setQueue(songs: songs, startAt: index, autoPlay: autoPlay)
        }
    }
    
    private var upcomingTracksDuration: Double {
        musicPlayerQueue
            .dropFirst(currentIndex + 1)
            .map(\.duration!)
            .reduce(0, +)
    }

    static func formatRemainingTime(
        currentTime: Double,
        duration: Double,
        upcomingDurations: Double,
        rate: Double
    ) -> String {
        let currentRemaining = max(duration - currentTime, 0)
        let safeRate = rate > 0 ? rate : 1.0
        let totalSec = (currentRemaining + upcomingDurations) / safeRate
        let m = Int(totalSec) / 60
        let s = Int(totalSec) % 60
        return String(format: "%02d:%02d", m, s)
    }
    
    // MARK: - Private
    private func bindService() {
        service.snapshotPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] snap in
                guard let self = self else { return }
                self.title       = snap.title
                self.artist      = snap.artist
                self.artwork     = snap.artwork
                self.currentTime = snap.currentTime
                self.duration    = snap.duration
                self.rate        = snap.rate
                self.isPlaying   = snap.isPlaying
                self.musicPlayerQueue = self.service.musicPlayerQueue
                self.currentIndex = self.service.nowPlayingIndex
                self.history = self.service.playHistory
            }
            .store(in: &cancellables)
    }
}
