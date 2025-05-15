import Combine
import MediaPlayer
import MusicKit
import SwiftUI

public actor MusicPlayerService: Sendable {
    private nonisolated(unsafe) let player = MPMusicPlayerController.applicationMusicPlayer
    private var songIDs: [MusicItemID] = []
    private var currentIndex: Int = 0
    
    private var storedRate: Double = Constants.MusicPlayer.defaultPlaybackRate
    private var defaultPlaybackRate: Double = Constants.MusicPlayer.defaultPlaybackRate
    private var minPlaybackRate: Double = Constants.MusicPlayer.minPlaybackRate
    private var maxPlaybackRate: Double = Constants.MusicPlayer.maxPlaybackRate
    
    public struct PlaybackSnapshot: Sendable {
        public let title: String
        public let artist: String
        public let artwork: Image
        public let currentTime: TimeInterval
        public let duration: TimeInterval
        public let rate: Double
        public let isPlaying: Bool
    }
    
    public nonisolated let snapshotSubject = PassthroughSubject<PlaybackSnapshot, Never>()
    public nonisolated var snapshotPublisher: AnyPublisher<PlaybackSnapshot, Never> {
        snapshotSubject.eraseToAnyPublisher()
    }
    
    private nonisolated(unsafe) var timeCancelable: AnyCancellable?
        
    public init() {
        player.beginGeneratingPlaybackNotifications()
        player.currentPlaybackRate = Float(defaultPlaybackRate)
        
        timeCancelable = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.handleTimerTick() }
            }
        
        NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: player,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { await self.handlePlaybackStateChange() }
        }
        
        NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: player,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { await self.handleNowPlayingItemChange() } }
    }
    
    deinit {
        player.endGeneratingPlaybackNotifications()
        NotificationCenter.default.removeObserver(self)
    }
    
    private func handleTimerTick() async {
        if player.playbackState == .playing {
            await publishSnapshot()
        }
    }
    
    private func handlePlaybackStateChange() async {
        if player.playbackState == .playing {
            player.currentPlaybackRate = Float(storedRate)
        }
        await publishSnapshot()
    }
    
    private func handleNowPlayingItemChange() async {
        refreshCurrentIndex()
        let idx = player.indexOfNowPlayingItem
        if idx != NSNotFound, idx < songIDs.count {
            currentIndex = idx
        } else {
            currentIndex = (currentIndex + 1) % songIDs.count
        }
        await publishSnapshot()
    }
    
    /// 再生キューのセットと開始位置
    public func setQueue(ids: [MusicItemID], startAt index: Int) {
        songIDs = ids
        currentIndex = index
        let descriptor = MPMusicPlayerStoreQueueDescriptor(storeIDs: ids.map(\.rawValue))
        player.setQueue(with: descriptor)
        player.nowPlayingItem = nil
        Task { await publishSnapshot() }
    }
    
    public func play() {
        player.play()
        player.currentPlaybackRate = Float(storedRate)
        Task {
            await publishSnapshot()
        }
    }
    public func pause() {
        player.currentPlaybackRate = Float(storedRate)
        player.pause()
        Task {
            await publishSnapshot()
        }
    }
    public func next() {
        player.skipToNextItem()
        currentIndex = (currentIndex + 1) % songIDs.count
        Task {
            await publishSnapshot()
        }
    }
    public func previous() {
        player.skipToPreviousItem()
        currentIndex = (currentIndex - 1 + songIDs.count) % songIDs.count
        Task {
            await publishSnapshot()
        }
    }
    public func seek(to time: TimeInterval) {
        let tmp = min(max(time, 0), duration)
        player.currentPlaybackTime = tmp
        if tmp >= duration - 0.05, songIDs.count > 1 {
            next()
            return
        }
        else {
            Task {
                await publishSnapshot()
            }
        }
    }
    public func changeRate(to newRate: Double) {
        storedRate = min(max(newRate, minPlaybackRate), maxPlaybackRate)
        player.currentPlaybackRate = Float(storedRate)
        Task {
            await publishSnapshot()
        }
    }
    
    public var currentTime: TimeInterval { player.currentPlaybackTime }
    public var duration: TimeInterval { player.nowPlayingItem?.playbackDuration ?? 0 }
    public var rate: Float { player.currentPlaybackRate }
    public var isPlaying: Bool { player.playbackState == .playing }
    
    /// カタログから現在トラックのメタ情報を取得
    public func currentSong() async throws -> Song? {
        guard songIDs.indices.contains(currentIndex) else { return nil }
        let req = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: songIDs[currentIndex])
        return try await req.response().items.first
    }
    
    public func currentArtworkImage(
        width: CGFloat = Constants.MusicPlayer.artworkSize,
        height: CGFloat = Constants.MusicPlayer.artworkSize
    ) async throws -> Image {
        guard let song = try await currentSong(),
              let url = song.artwork?.url(width: Int(width), height: Int(height)),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let uiImg = UIImage(data: data)
        else {
            return Image(systemName: "music.note")
        }
        return Image(uiImage: uiImg)
    }
    
    private func publishSnapshot() async {
        refreshCurrentIndex()
        let song = try? await currentSong()
        let img = (try? await currentArtworkImage()) ?? Image(systemName: "music.note")
        snapshotSubject.send(.init(
            title: song?.title ?? "-",
            artist: song?.artistName ?? "-",
            artwork: img,
            currentTime: currentTime,
            duration: duration,
            rate: storedRate,
            isPlaying: isPlaying
        ))
    }
    private func refreshCurrentIndex() {
        guard
            let id = player.nowPlayingItem?.playbackStoreID,
            let idx = songIDs.firstIndex(where: { $0.rawValue == id })
        else { return }
        currentIndex = idx
    }
}
