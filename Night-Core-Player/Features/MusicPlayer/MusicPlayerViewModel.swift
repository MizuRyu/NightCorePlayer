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
    
    func setQueue(_ songs: [Song], startAt idx: Int) {
        Task { await service.setQueue(songs: songs, startAt: idx) }
    }
    func moveQueueItem(from src: Int, to dst: Int) {
        Task {
            await service.moveItem(from: src, to: dst)
        }
    }
    func removeQueueItems(at offsets: IndexSet) {
        Task {
            for idx in offsets.sorted(by: >) {
                removeQueueItem(at: idx)
            }
        }
    }

    func removeQueueItem(at idx: Int) {
        Task { await service.removeItem(at: idx) }
    }
    
    func playNow(_ song: Song) {
        Task {
            await service.playNow(song)
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
        Task { 
            await service.clearHistory()
            self.history = []
            }
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
            await service.setQueue(songs: songs, startAt: index)
            if autoPlay { await service.play() }
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
