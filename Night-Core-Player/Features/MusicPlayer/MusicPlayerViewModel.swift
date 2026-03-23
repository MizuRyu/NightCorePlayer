import SwiftUI
import MusicKit
import MediaPlayer
import Combine
import Observation

@Observable
@MainActor
final class MusicPlayerViewModel {
    private(set) var musicPlayerQueue: [Song] = []
    private(set) var currentIndex: Int = 0
    private(set) var history: [Song] = []
    
    private(set) var title: String      = "—"
    private(set) var artist: String     = "—"
    private(set) var artworkData: Data?  = nil
    private(set) var currentTime: Double = 0

    var artworkImage: Image {
        if let data = artworkData, let ui = UIImage(data: data) {
            return Image(uiImage: ui)
        }
        return Image(systemName: "music.note")
    }
    private(set) var duration: Double    = 0
    private(set) var rate: Double        = Constants.MusicPlayer.defaultPlaybackRate
    private(set) var isPlaying: Bool     = false
    private(set) var isShuffled: Bool    = false
    private(set) var repeatMode: Constants.RepeatMode = .none
    private(set) var isAutoPlayEnabled: Bool = false
    var errorMessage: String?

    private var skipSeconds: Double = Constants.MusicPlayer.skipSeconds

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
        Task {
            await service.setQueue(songs: songs, startAt: idx, autoPlay: autoPlay)
            self.musicPlayerQueue = service.musicPlayerQueue
            self.currentIndex = service.nowPlayingIndex
        }
    }

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
            self.musicPlayerQueue = service.musicPlayerQueue
            self.currentIndex = service.nowPlayingIndex
        }
    }
    func playNowNext(_ song: Song) {
        Task {
            await service.playNextAndPlay(song)
            self.musicPlayerQueue = service.musicPlayerQueue
            self.currentIndex = service.nowPlayingIndex
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
        do {
            try service.clearHistory()
            self.history = []
        } catch {
            errorMessage = (error as? AppError)?.errorDescription ?? error.localizedDescription
        }
    }
    
    func toggleShuffle() {
        Task { await service.toggleShuffle() }
    }
    
    func cycleRepeatMode() {
        Task { await service.cycleRepeatMode() }
    }
    
    func toggleAutoPlay() {
        Task { await service.toggleAutoPlay() }
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
        Task { await service.setSessionRate(tmp) }
    }
    func adjustRate(by delta: Double) {
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
    
    private func bindService() {
        service.snapshotPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snap in
                guard let self else { return }
                self.title       = snap.title
                self.artist      = snap.artist
                self.artworkData = snap.artworkData
                self.currentTime = snap.currentTime
                self.duration    = snap.duration
                self.rate        = snap.rate
                self.isPlaying   = snap.isPlaying
                self.isShuffled  = self.service.isShuffled
                self.repeatMode  = self.service.repeatMode
                self.isAutoPlayEnabled = self.service.isAutoPlayEnabled
                self.musicPlayerQueue = self.service.musicPlayerQueue
                self.currentIndex = self.service.nowPlayingIndex
                self.history = self.service.playHistory
            }
            .store(in: &cancellables)
    }
}
