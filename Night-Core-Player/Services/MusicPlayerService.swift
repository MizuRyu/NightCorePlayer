import Combine
import MediaPlayer
import MusicKit
import SwiftUI

public struct MusicPlayerSnapshot: Sendable {
    public let title: String
    public let artist: String
    public let artwork: Image
    public let currentTime: TimeInterval
    public let duration: TimeInterval
    public let rate: Double
    public let isPlaying: Bool
}

@MainActor
protocol MusicPlayerService: Sendable {
    var snapshotPublisher: AnyPublisher<MusicPlayerSnapshot, Never> { get }
    
    func setQueue(ids: [MusicItemID], startAt index: Int) async
    func play() async
    func pause() async
    func next() async
    func previous() async
    func seek(to time: TimeInterval) async
    func changeRate(to newRate: Double) async
    
    func currentSong() async throws -> Song?
    func currentArtworkImage(width: CGFloat, height: CGFloat) async throws -> Image
}

@MainActor
public final class MusicPlayerServiceImpl: MusicPlayerService {
    private nonisolated(unsafe) let player = MPMusicPlayerController.applicationMusicPlayer
    private var songIDs: [MusicItemID] = []
    private var currentIndex: Int = 0
    
    private var storedRate: Double = Constants.MusicPlayer.defaultPlaybackRate
    private var defaultPlaybackRate: Double = Constants.MusicPlayer.defaultPlaybackRate
    private var minPlaybackRate: Double = Constants.MusicPlayer.minPlaybackRate
    private var maxPlaybackRate: Double = Constants.MusicPlayer.maxPlaybackRate
    
    private let snapshotSubject = PassthroughSubject<MusicPlayerSnapshot, Never>()
    public var snapshotPublisher: AnyPublisher<MusicPlayerSnapshot, Never> {
        snapshotSubject.eraseToAnyPublisher()
    }
    
    private var timeCancelable: AnyCancellable?
        
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
    
    // 0.5秒経過時、再生時間UI更新
    private func handleTimerTick() async {
        if player.playbackState == .playing {
            await publishSnapshot()
        }
    }
    
    // 再生状態変更時、UI更新
    private func handlePlaybackStateChange() async {
        if player.playbackState == .playing {
            player.currentPlaybackRate = Float(storedRate)
        }
        await publishSnapshot()
    }
    
    // 曲変更時、UI更新
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
    public func setQueue(ids: [MusicItemID], startAt index: Int) async {
        songIDs = ids
        currentIndex = index
        
        let descriptor = MPMusicPlayerStoreQueueDescriptor(storeIDs: ids.map(\.rawValue))
        descriptor.startItemID = ids[index].rawValue
        
        player.setQueue(with: descriptor)
        player.nowPlayingItem = nil
        
        await publishSnapshot()
    }
    
    public func play() async {
        player.play()
        player.currentPlaybackRate = Float(storedRate)
        await publishSnapshot()
    }
    public func pause() async {
        player.currentPlaybackRate = Float(storedRate)
        player.pause()
        await publishSnapshot()

    }
    public func next() async {
        player.skipToNextItem()
        currentIndex = (currentIndex + 1) % songIDs.count
        await publishSnapshot()

    }
    public func previous() async {
        player.skipToPreviousItem()
        currentIndex = (currentIndex - 1 + songIDs.count) % songIDs.count
        await publishSnapshot()

    }
    public func seek(to time: TimeInterval) async {
        let tmp = min(max(time, 0), player.nowPlayingItem?.playbackDuration ?? 0)
        player.currentPlaybackTime = tmp
        if tmp >= (player.nowPlayingItem?.playbackDuration ?? 0) - 0.05, songIDs.count > 1 {
            await next()
            return
        }
        else {
            await publishSnapshot()
        }
    }
    public func changeRate(to newRate: Double) async {
        storedRate = min(max(newRate, minPlaybackRate), maxPlaybackRate)
        player.currentPlaybackRate = Float(storedRate)
        await publishSnapshot()
    }
    
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
        let title = song?.title ?? "-"
        let artist = song?.artistName ?? "-"
        let artwork = (try? await currentArtworkImage()) ?? Image(systemName: "music.note")
        let current = player.currentPlaybackTime
        let total = player.nowPlayingItem?.playbackDuration ?? 0
        let playing = player.playbackState == .playing
        
        snapshotSubject.send(
            .init(
                title: title,
                artist: artist,
                artwork: artwork,
                currentTime: current,
                duration: total,
                rate: storedRate,
                isPlaying: playing
            )
        )
    }
    private func refreshCurrentIndex() {
        guard
            let id = player.nowPlayingItem?.playbackStoreID,
            let idx = songIDs.firstIndex(where: { $0.rawValue == id })
        else { return }
        currentIndex = idx
    }
}
