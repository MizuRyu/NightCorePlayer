import SwiftUI
import MusicKit
import MediaPlayer
import Combine

@MainActor
final class MusicPlayerViewModel: ObservableObject {
    private var songIDs: [MusicItemID] = []
    
    @Published private(set) var title: String      = "—"
    @Published private(set) var artist: String     = "—"
    @Published private(set) var artwork: Image     = Image(systemName: "music.note")
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double    = 0
    @Published private(set) var rate: Double        = Constants.MusicPlayer.defaultPlaybackRate
    @Published private(set) var isPlaying: Bool     = false

    private var skipSeconds: Double = Constants.MusicPlayer.skipSeconds
    
    // MARK: - Dependencies
    private let service: MusicPlayerService
    private var cancellables = Set<AnyCancellable>()
    
    init(service: MusicPlayerService) {
        self.service = service
        bindService()
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
    
    func loadPlaylist(ids: [MusicItemID], startAt index: Int = 0, autoPlay: Bool = true) {
        Task {
            await service.setQueue(ids: ids, startAt: index)
            if autoPlay { await service.play() }
        }
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
            }
            .store(in: &cancellables)
    }
}
