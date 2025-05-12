import SwiftUI
import MusicKit
import MediaPlayer
import Combine

@MainActor
class MusicPlayerViewModel: ObservableObject {
    
    // Dummy
    private let songIDs: [MusicItemID] = [
        MusicItemID("1752838890"),
        MusicItemID("1679278167"),
        MusicItemID("1490256995")
    ]
    
    @Published private(set) var currentTrackIndex: Int = 0
    @Published private(set) var trackTitle: String = ""
    @Published private(set) var artistName: String = ""
    @Published private(set) var artworkImage: Image = Image("music.note")
    
    @Published var currentTime: Double = 0
    @Published var musicDuration: Double = 240
    @Published var rate: Double = 1.0
    @Published var isPlaying: Bool = true
    
    private let player = MPMusicPlayerController.applicationMusicPlayer
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        Task { await authorizeAndLoadFirstTrack() }
    }
    
    deinit { cancellables.forEach { $0.cancel() } }
    
    
    func previousTrack() {
        changeTrack(to: (currentTrackIndex - 1 + songIDs.count) % songIDs.count)
        
    }
    func nextTrack() {
        changeTrack(to: (currentTrackIndex + 1 + songIDs.count) % songIDs.count)
        
    }
    
    func togglePlayPause() {
        isPlaying ? pause() : play()
    }
    
    func play() {
        player.play()
        isPlaying = true
        
    }
    
    func pause() {
        player.pause()
        isPlaying = false
    }
    
    // 倍速調整
    func changeRate(by delta: Double) {
        setRate(to: rate + delta)
    }
    func setRate(to newRate: Double) {
        let tmp = min(max(newRate, 0.5), 3.0)
        rate = tmp
        player.currentPlaybackRate = Float(tmp)
    }
    func rewind15() {
        seek(by: -15)
    }
    func forward15() {
        seek(by: +15)
    }
    
    func seek(to time: Double) {
        player.currentPlaybackTime = time
        currentTime = time
    }
    
    private func seek(by delta: Double) {
        let newTime = min(max(currentTime + delta, 0), musicDuration)
        player.currentPlaybackTime = newTime
        currentTime = newTime
    }
    
    private func changeTrack(to newIndex: Int) {
        Task { await loadTrack(at: newIndex, autoPlay : true) }
    }
    
    private func authorizeAndLoadFirstTrack() async {
        let status = await MusicAuthorization.request()
        guard status == .authorized else { return }
        await loadTrack(at: currentTrackIndex, autoPlay: false)
        observePlayer()
    }
    
    private func loadTrack(at index: Int, autoPlay: Bool) async {
        currentTrackIndex = index
        
        do {
            let req = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: songIDs[index])
            guard let song = try await req.response().items.first else { return }
            trackTitle = song.title
            artistName = song.artistName
            musicDuration = song.duration ?? 0
           if let url = song.artwork?.url(width: 300, height: 300),
               let (data, _) = try? await URLSession.shared.data(from: url),
               let uiImg = UIImage(data: data) {
                artworkImage = Image(uiImage: uiImg)
            } else {
                artworkImage = Image(systemName: "music.note")
            }
            player.setQueue(with: [song.id.rawValue])
            if autoPlay { player.play() }
            isPlaying = autoPlay
        } catch {
            print("MusicKit load error", error)
        }
    }
    
    private func observePlayer() {
        // MediaPlayer には Combine Publisher が無いため Timer 監視に差し替え
        Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.currentTime = self.player.currentPlaybackTime
            }
            .store(in: &cancellables)
    }
}
