import SwiftUI
import AVFoundation

@MainActor
class MusicPlayerViewModel: ObservableObject {
    struct Track {
        let title: String
        let artist: String
        let artworkName: String
        let fileURL: URL
    }
    
    private lazy var tracks: [Track] = [
        .init(
            title: "title1",
            artist: "artist1",
            artworkName: "imgAssets1",
            fileURL: Bundle.main.url(forResource: "track1", withExtension: "mp4")!
        ),
        .init(
            title: "title2",
            artist: "artist2",
            artworkName: "imgAssets2",
            fileURL: Bundle.main.url(forResource: "track2", withExtension: "mp4")!
        )
    ]
    
    @Published private(set) var currentTrackIndex: Int = 0
    @Published private(set) var trackTitle: String = ""
    @Published private(set) var artistName: String = ""
    @Published private(set) var artworkImage: Image = Image("")
    
    @Published var currentTime: Double = 0
    @Published var musicDuration: Double = 240
    @Published var rate: Double = 1.0
    @Published var isPlaying: Bool = true
    
    private var player: AVPlayer?
    private var timeObserverToken: Any?
    private var endObserver: Any?
    
    init() {
        loadTrack(at: currentTrackIndex, autoPlay: false)
    }
    
    deinit {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
        }
        if let endObserver = endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }
    
    
    func previousTrack() {
        changeTrack(to: (currentTrackIndex - 1 + tracks.count) % tracks.count)
        
    }
    func nextTrack() {
        changeTrack(to: (currentTrackIndex + 1 + tracks.count) % tracks.count)
    }
    
    func togglePlayPause() {
        isPlaying ? pause() : play()
    }
    
    func play() {
        if timeObserverToken == nil {
            addPeriodicTimeObserver()
        }
        player?.playImmediately(atRate: Float(rate))
        isPlaying = true
        
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
    }
    
    // 倍速調整
    func changeRate(by delta: Double) {
        setRate(to: rate + delta)
    }
    func setRate(to newRate: Double) {
        let tmp = min(max(newRate, 0.5), 3.0)
        rate = tmp
        if isPlaying {
            player?.rate = Float(tmp)
        }
    }
    func rewind15() {
        seek(by: -15)
    }
    func forward15() {
        seek(by: +15)
    }
    
    func seek(to time: Double) {
        guard let player = player else { return }
        let cm = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cm)
        currentTime = time
    }
    
    private func seek(by delta: Double) {
        guard let player = player else { return }
        let current = player.currentTime().seconds
        let newTime = min(max(current + delta, 0), musicDuration)
        player.seek(to: CMTime(seconds: newTime, preferredTimescale: 600))
        currentTime = newTime
    }
    
    private func changeTrack(to newIndex: Int) {
        // 停止・Observer削除
        player?.pause()
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        // 読み込み
        loadTrack(at: newIndex, autoPlay: true)
    }
    
    
    private func loadTrack(at index: Int, autoPlay: Bool) {
        currentTrackIndex = index
        let t = tracks[index]
        trackTitle = t.title
        artistName = t.artist
        artworkImage = Image(t.artworkName)
        
        // AVPlayer setup
        let item = AVPlayerItem(url: t.fileURL)
        player = AVPlayer(playerItem: item)
        
        if let obs = endObserver {
            NotificationCenter.default.removeObserver(obs)
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main,
        ) { [weak self] _ in
            Task { @MainActor in
                self?.nextTrack()
            }
        }
        
        // 再生時間取得
        Task { @MainActor in
            let durationCM = try? await item.asset.load(.duration)
            let secs = durationCM?.seconds ?? 0
            musicDuration = secs.isFinite ? secs : 0
        }
        
        addPeriodicTimeObserver()
        
        if autoPlay {
            play()
        }
    }
    
    private func addPeriodicTimeObserver() {
        guard timeObserverToken == nil, let player = player else { return }
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                self?.currentTime = time.seconds
            }
        }
    }
}
