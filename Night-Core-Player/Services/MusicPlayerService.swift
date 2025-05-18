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
    
    func setQueue(songs: [Song], startAt index: Int) async
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
    private let player = MPMusicPlayerController.applicationMusicPlayer
    private var songIDs: [MusicItemID] = []
    private var songs: [Song] = []
    
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
        let idx = player.indexOfNowPlayingItem
        await publishSnapshot()
    }
    
    /// 再生キューのセットと開始位置
    public func setQueue(songs: [Song], startAt index: Int) async {
        guard !songs.isEmpty else {
            self.songs = []
            await publishSnapshot()
            return
        }
        
        self.songs = songs
        self.songIDs = songs.map(\.id)
        let safeIndex = min(max(index, 0), songIDs.count - 1)
        
        let rotatedSongs = Array(songs[safeIndex...] + songs[..<safeIndex])
        
        // ライブラリ、カタログ両方に対応するPlayerDescriptorを作成        
        let playParams: [MPMusicPlayerPlayParameters] = rotatedSongs.compactMap { song in
            guard let pp = song.playParameters else { return nil }
            do {
                let data = try JSONEncoder().encode(pp)
                return try JSONDecoder().decode(MPMusicPlayerPlayParameters.self, from: data)
            } catch {
                return nil
            }
        }
        let descriptor = MPMusicPlayerPlayParametersQueueDescriptor(
            playParametersQueue: playParams
            )
        
        player.setQueue(with: descriptor)

        await play()
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
        await publishSnapshot()

    }
    public func previous() async {
        player.skipToPreviousItem()
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
        let playerIndex = player.indexOfNowPlayingItem
        guard songIDs.indices.contains(playerIndex) else { return nil }
        let req = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: songIDs[playerIndex])
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
        let currentTime = player.currentPlaybackTime
        let duration    = player.nowPlayingItem?.playbackDuration ?? 0
        let isPlaying   = player.playbackState == .playing
        let rate        = storedRate
        
        // MPMediaItem (ローカル) からメタ情報取得
        var title   = "-"
        var artist  = "-"
        var artwork = Image(systemName: "music.note")
        var hasLocalArtwork = false
        
        if let mediaItem = player.nowPlayingItem {
            title  = mediaItem.title  ?? "-"
            artist = mediaItem.artist ?? "-"
            
            if let art = mediaItem.artwork?
                .image(at: CGSize(
                    width: Constants.MusicPlayer.artworkSize,
                    height: Constants.MusicPlayer.artworkSize
                )) {
                artwork = Image(uiImage: art)
                hasLocalArtwork = true
            }
        }
        
        // ローカルにない、カタログ楽曲である場合、network経由で取得
        if !hasLocalArtwork {
            if let song = try? await currentSong(),
               let url  = song.artwork?.url(
                width: Int(Constants.MusicPlayer.artworkSize),
                height: Int(Constants.MusicPlayer.artworkSize)
               ),
               let (data, _) = try? await URLSession.shared.data(from: url),
               let uiImg     = UIImage(data: data)
            {
                artwork = Image(uiImage: uiImg)
            }
        }
        
        snapshotSubject.send(
            .init(
                title: title,
                artist: artist,
                artwork: artwork,
                currentTime: currentTime,
                duration:    duration,
                rate:        rate,
                isPlaying:   isPlaying
            )
        )
    }
}
