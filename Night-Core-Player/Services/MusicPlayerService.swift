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
protocol PlayerControllable: Sendable {
    var playbackState: MPMusicPlaybackState { get }
    var currentTime: TimeInterval { get }
    var nowPlayingItem: MPMediaItem? { get }
    var indexOfNowPlayingItem: Int { get }
    var playbackRate: Double { get set }

    func play()
    func pause()
    func seek(to time: TimeInterval)
    func skipToNext()
    func skipToPrevious()
    func setQueue(with descriptor: MPMusicPlayerPlayParametersQueueDescriptor)
    func prepend(_ descriptor: MPMusicPlayerPlayParametersQueueDescriptor)
    func stop()
}

@MainActor
final class MPMusicPlayerAdapter: PlayerControllable {
    private let player = MPMusicPlayerController.applicationQueuePlayer

    init(defaultRate: Double) {
        player.beginGeneratingPlaybackNotifications()
        player.currentPlaybackRate = Float(defaultRate)
    }

    deinit {
        player.endGeneratingPlaybackNotifications()
    }

    var playbackState: MPMusicPlaybackState { player.playbackState }
    var currentTime: TimeInterval { player.currentPlaybackTime }
    var nowPlayingItem: MPMediaItem? { player.nowPlayingItem }
    var indexOfNowPlayingItem: Int { player.indexOfNowPlayingItem }
    var playbackRate: Double {
        get { Double(player.currentPlaybackRate) }
        set { player.currentPlaybackRate = Float(newValue) }
    }

    func play() { player.play() }
    func pause() { player.pause() }
    func seek(to time: TimeInterval) { player.currentPlaybackTime = time }
    func skipToNext() { player.skipToNextItem() }
    func skipToPrevious() { player.skipToPreviousItem() }
    func setQueue(with descriptor: MPMusicPlayerPlayParametersQueueDescriptor) { player.setQueue(with: descriptor) }
    func prepend(_ descriptor: MPMusicPlayerPlayParametersQueueDescriptor) { player.prepend(descriptor) }
    func stop() { player.stop() }
}

// MARK: - Utilities
struct MusicPlayerUtils {
    // プレイリスト（ローカル）からPlayeParametersを抽出するため
    static func makePlayParameters(for song: Song) throws -> MPMusicPlayerPlayParameters? {
        guard let playParams = song.playParameters else {
            return nil
        }
        let data = try JSONEncoder().encode(playParams)
        let pp   = try JSONDecoder().decode(MPMusicPlayerPlayParameters.self, from: data)
        return pp
    }

    static func buildQueueDescriptor(from songs: [Song], startAt index: Int) throws -> MPMusicPlayerPlayParametersQueueDescriptor? {
        guard !songs.isEmpty, songs.indices.contains(index) else { return nil }
        let rotated = Array(songs[index...] + songs[..<index])
        let params = try rotated.compactMap { try makePlayParameters(for: $0) }
        guard !params.isEmpty else { return nil }
        return MPMusicPlayerPlayParametersQueueDescriptor(playParametersQueue: params)
    }
}

enum QueueUpdateAction: Sendable {
    case playNewQueue
    case updatePlayerQueueOnly
    case playCurrentTrack
    case playerShouldStop
    case noAction
}

@MainActor
protocol QueueManaging: Sendable {
    var items: [Song] { get }
    var currentIndex: Int { get }
    var currentSong: Song? { get }
    var isEmpty: Bool { get }

    func setQueue(_ songs: [Song], startAt idx: Int) async -> QueueUpdateAction
    func moveItem(from src: Int, to dst: Int) async -> QueueUpdateAction
    func removeItem(at idx: Int) async -> (action:QueueUpdateAction, removed: Song?)
    func insertNext(_ song: Song) async -> (action: QueueUpdateAction, newIndex: Int?)
    func advanceToNextTrack() async -> Bool
    func regressToPreviousTrack() async -> Bool
    func songsForPlayerQueueDescriptor() async -> [Song]
}

@MainActor
final class MusicQueueManager: QueueManaging {
    private(set) var items: [Song] = []
    private(set) var currentIndex: Int = 0

    var isEmpty: Bool { items.isEmpty }
    var currentSong: Song? {
        guard items.indices.contains(currentIndex) else { return nil }
        return items[currentIndex]
    }

    func setQueue(_ songs: [Song], startAt idx: Int) async -> QueueUpdateAction {
        items = songs
        if songs.isEmpty {
            currentIndex = 0
            return .playerShouldStop
        }
        currentIndex = min(max(idx, 0), songs.count - 1)
        return .playNewQueue
    }

    func moveItem(from src: Int, to dst: Int) async -> QueueUpdateAction {
        guard src != dst,
              items.indices.contains(src),
              items.indices.contains(dst) else { return .noAction }
        let song = items.remove(at: src)
        items.insert(song, at: dst)
        if src == currentIndex { currentIndex = dst }
        else if src < currentIndex && dst >= currentIndex { currentIndex -= 1 }
        else if src > currentIndex && dst <= currentIndex { currentIndex += 1 }
        return .updatePlayerQueueOnly
    }

    func removeItem(at idx: Int) async -> (action: QueueUpdateAction, removed: Song?) {
        guard items.indices.contains(idx) else { return (.noAction, nil) }
        let removed = items.remove(at: idx)
        if items.isEmpty {
            currentIndex = 0
            return (.playerShouldStop, removed)
        }
        let oldIndex = currentIndex
        if idx < oldIndex {
            currentIndex -= 1
            return (.updatePlayerQueueOnly, removed)
        } else if idx == oldIndex {
            currentIndex = min(oldIndex, items.count - 1)
            return (.playNewQueue, removed)
        }
        return (.updatePlayerQueueOnly, removed)
    }

    func insertNext(_ song: Song) async -> (action: QueueUpdateAction, newIndex: Int?) {
        if items.isEmpty {
            items = [song]
            currentIndex = 0
            return (.playNewQueue, 0)
        }
        let insertAt = currentIndex + 1
        items.insert(song, at: insertAt)
        return (.updatePlayerQueueOnly, insertAt)
    }

    func advanceToNextTrack() async -> Bool {
        guard currentIndex + 1 < items.count else { return false }
        currentIndex += 1
        return true
    }

    func regressToPreviousTrack() async -> Bool {
        guard currentIndex > 0 else { return false }
        currentIndex -= 1
        return true
    }

    func songsForPlayerQueueDescriptor() async -> [Song] {
        guard !items.isEmpty else { return [] }
        return Array(items[currentIndex...] + items[..<currentIndex])
    }
}

@MainActor
protocol HistoryManaging: Sendable {
    var history: [Song] { get }
    func append(_ song: Song) async
    func clear() async
}

@MainActor
final class MusicHistoryManager: HistoryManaging {
    private(set) var history: [Song] = []

    func append(_ song: Song) async {
        if let last = history.last, last.id == song.id {
            return
        }
        
        history.append(song)
        
        let titles = history.map { $0.title }
        print("📜 [History] Now:", titles)
    }

    func clear() async {
        history.removeAll()
    }
}

@MainActor
protocol MetadataFetching: Sendable {
    func fetchSongDetails(song: Song) async throws -> Song?
    func fetchArtworkImage(_ artwork: Artwork?, width: CGFloat, height: CGFloat) async -> Image
}

@MainActor
final class MusicMetadataFetcher: MetadataFetching {
    func fetchSongDetails(song: Song) async throws -> Song? {
        let raw = song.id.rawValue
        if raw.hasPrefix("i.") {
            print("📚 Library track, skipping catalog lookup: \(raw)")
            return song
        }
        let req = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: song.id)
        let resp = try await req.response()
        return resp.items.first
    }

    func fetchArtworkImage(_ artwork: Artwork?, width: CGFloat, height: CGFloat) async -> Image {
        guard let art = artwork,
              let url = art.url(width: Int(width), height: Int(height)) else {
            return Image(systemName: "music.note")
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let ui = UIImage(data: data) {
                return Image(uiImage: ui)
            }
        } catch {
            print("Artwork load error:", error)
        }
        return Image(systemName: "music.note")
    }
}

@MainActor
final class SnapshotBuilder {
    private let player: PlayerControllable
    private let queue: QueueManaging
    private let history: HistoryManaging
    private let metadata: MetadataFetching

    init(
        player: PlayerControllable,
        queue: QueueManaging,
        history: HistoryManaging,
        metadata: MetadataFetching
    ) {
        self.player = player
        self.queue = queue
        self.history = history
        self.metadata = metadata
    }

    func buildSnapshot(currentRate: Double) async -> MusicPlayerSnapshot {
        let currentTime = player.currentTime
        let isPlaying = player.playbackState == .playing

        var title = player.nowPlayingItem?.title ?? "-"
        var artist = player.nowPlayingItem?.artist ?? "-"
        var duration = player.nowPlayingItem?.playbackDuration ?? 0
        var artwork = Image(systemName: "music.note")

        if let song = await queue.currentSong {
            if let item = try? await metadata.fetchSongDetails(song: song) {
                title = item.title
                artist = item.artistName
                duration = item.duration ?? duration
                artwork = await metadata.fetchArtworkImage(item.artwork, width: Constants.MusicPlayer.artworkSize, height: Constants.MusicPlayer.artworkSize)
            } else {
                artwork = await metadata.fetchArtworkImage(song.artwork, width: Constants.MusicPlayer.artworkSize, height: Constants.MusicPlayer.artworkSize)
            }
        }

        return .init(
            title: title,
            artist: artist,
            artwork: artwork,
            currentTime: currentTime,
            duration: duration,
            rate: currentRate,
            isPlaying: isPlaying
        )
    }
}

@MainActor
final class PlaybackEventRouter {
    private var timerCancellable: AnyCancellable?
    private let player: PlayerControllable
    private let builder: SnapshotBuilder
    private let history: HistoryManaging
    private let subject: PassthroughSubject<MusicPlayerSnapshot, Never>
    private weak var service: MusicPlayerServiceImpl?

    init(
        player: PlayerControllable,
        builder: SnapshotBuilder,
        history: HistoryManaging,
        subject: PassthroughSubject<MusicPlayerSnapshot, Never>,
        service: MusicPlayerServiceImpl
    ) {
        self.player  = player
        self.builder = builder
        self.history = history
        self.subject = subject
        self.service = service

        // 0.5秒経過時、再生時間UI更新
        timerCancellable = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in Task { await self?.publishIfPlaying() } }

        let mp = MPMusicPlayerController.applicationQueuePlayer
        // 再生状態変更時、UI更新
        NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: mp, queue: .main
        ) { [weak self] _ in Task { await self?.publishSnapshot() } }
        // 曲変更時、UI更新
        NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: mp, queue: .main
        ) { [weak self] _ in Task { await self?.itemChanged() } }
    }

    deinit {
        timerCancellable?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    private func publishIfPlaying() async {
        if player.playbackState == .playing {
            await publishSnapshot()
        }
    }

    private func publishSnapshot() async {
        guard let svc = service else { return }
        let snap = await builder.buildSnapshot(currentRate: svc.currentPlaybackRate)
        subject.send(snap)
    }

    private func itemChanged() async {
        if let prev = await queueCurrentHistoryCandidate() {
            await history.append(prev)
        }
        await publishSnapshot()
    }

    private func queueCurrentHistoryCandidate() async -> Song? {
        guard let svc = service,
              svc.nowPlayingIndex > 0 else { return nil }
        let idx = svc.nowPlayingIndex - 1
        let queue = svc.musicPlayerQueue
        guard queue.indices.contains(idx) else { return nil }
        return queue[idx]
    }
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
    
    var musicPlayerQueue: [Song] { get }
    var nowPlayingIndex: Int { get }
    
    func moveItem(from src: Int, to dst: Int) async
    func removeItem(at idx: Int) async
    func playNow(_ song: Song) async
    
    func insertNext(_ song: Song) async
    
    // 再生履歴
    var history: [Song] { get }
    func appendToHistory(_ song: Song) async
    func clearHistory() async
    
    func currentSong() async throws -> Song?
    func currentArtworkImage(width: CGFloat, height: CGFloat) async throws -> Image
}

@MainActor
public final class MusicPlayerServiceImpl: MusicPlayerService {
    public var snapshotPublisher: AnyPublisher<MusicPlayerSnapshot, Never> {
        snapshotSubject.eraseToAnyPublisher()
    }

    private var playerAdapter: PlayerControllable
    private let queueManager: QueueManaging
    private let historyManager: HistoryManaging
    private let snapshotBuilder: SnapshotBuilder
    private let metadataFetcher: MetadataFetching
    private let snapshotSubject = PassthroughSubject<MusicPlayerSnapshot, Never>()

    private lazy var eventRouter: PlaybackEventRouter = {
        PlaybackEventRouter(
            player: playerAdapter,
            builder: snapshotBuilder,
            history: historyManager,
            subject: snapshotSubject,
            service: self)
    }()

    
    private let defaultPlaybackRate: Double = Constants.MusicPlayer.defaultPlaybackRate
    var currentPlaybackRate: Double = Constants.MusicPlayer.defaultPlaybackRate
    private let minPlaybackRate: Double = Constants.MusicPlayer.minPlaybackRate
    private let maxPlaybackRate: Double = Constants.MusicPlayer.maxPlaybackRate
    
    
    private var timeCancelable: AnyCancellable?
    private var queueNeedsRebuild: Bool = false
        
    public init() {
        playerAdapter = MPMusicPlayerAdapter(defaultRate: currentPlaybackRate)
        queueManager = MusicQueueManager()
        historyManager = MusicHistoryManager()
        metadataFetcher = MusicMetadataFetcher()
        snapshotBuilder = SnapshotBuilder(
            player: playerAdapter,
            queue: queueManager,
            history: historyManager,
            metadata: metadataFetcher
        )
        eventRouter = PlaybackEventRouter(
            player: playerAdapter,
            builder: snapshotBuilder,
            history: historyManager,
            subject: snapshotSubject,
            service: self
        )
    }

    public var musicPlayerQueue: [Song] { queueManager.items }
    public var nowPlayingIndex: Int { queueManager.currentIndex }
    public var history: [Song] { historyManager.history }

    public func setQueue(songs: [Song], startAt idx: Int) async {
        let action = await queueManager.setQueue(songs, startAt: idx)
        await handleQueueAction(action)
    }
    
    public func play() async {
        playerAdapter.play()
        playerAdapter.playbackRate = currentPlaybackRate
    }
    public func pause() async {
        playerAdapter.pause()

    }
    public func next() async {
        // ユーザーが再生キューを操作した場合、キューを新規作成
        if queueNeedsRebuild {
            queueNeedsRebuild = false
            let advanced = await queueManager.advanceToNextTrack()
            if advanced {
                await handleQueueAction(.playNewQueue)
            }
        }
        else if await queueManager.advanceToNextTrack()
        {
            playerAdapter.skipToNext()
        }
    }
    public func previous() async {
        _ = await queueManager.regressToPreviousTrack()
        playerAdapter.skipToPrevious()
    }

    // 自動スキップ時
    public func seek(to time: TimeInterval) async {
        let dur = playerAdapter.nowPlayingItem?.playbackDuration ?? 0
        let t   = Swift.min(Swift.max(time, 0), dur)
        playerAdapter.seek(to: t)
        if t >= dur - 0.05, await queueManager.items.count > 1 {
            if queueNeedsRebuild {
                queueNeedsRebuild = false
                let advanced = await queueManager.advanceToNextTrack()
                if advanced {
                    await handleQueueAction(.playNewQueue)
                }
            } else {
                await next()
            }
        }
    }
    public func changeRate(to newRate: Double) async {
        currentPlaybackRate = Swift.min(Swift.max(newRate, minPlaybackRate), maxPlaybackRate)
        playerAdapter.playbackRate = currentPlaybackRate
    }

    public func moveItem(from src: Int, to dst: Int) async {
        let _ = await queueManager.moveItem(from: src, to: dst)
        // 次の楽曲再生時、再生キューをリビルドする
        queueNeedsRebuild = true
    }

    public func removeItem(at idx: Int) async {
        let (action, _) = await queueManager.removeItem(at: idx)
        await handleQueueAction(action)
    }

    public func playNow(_ song: Song) async {
        let action = await queueManager.setQueue([song], startAt: 0)
        await handleQueueAction(action)
    }

    public func insertNext(_ song: Song) async {
        let (action, _) = await queueManager.insertNext(song)
        if action == .playNewQueue {
            // キューが空である場合
            await handleQueueAction(action)
            return
        }
        if let pp = try? MusicPlayerUtils.makePlayParameters(for: song) {
            playerAdapter.prepend(MPMusicPlayerPlayParametersQueueDescriptor(playParametersQueue: [pp]))
        }
    }

    public func appendToHistory(_ song: Song) async {
        await historyManager.append(song)
    }

    public func clearHistory() async {
        await historyManager.clear()
    }

    public func currentSong() async throws -> Song? {
        guard let s = await queueManager.currentSong else { return nil }
        return try await metadataFetcher.fetchSongDetails(song: s) ?? s
    }

    public func currentArtworkImage(width: CGFloat = Constants.MusicPlayer.artworkSize,
                                    height: CGFloat = Constants.MusicPlayer.artworkSize) async throws -> Image {
        let song = try await currentSong()
        return await metadataFetcher.fetchArtworkImage(song?.artwork, width: width, height: height)
    }

    private func debugPrintQueue(_ context: String) {
        print("—— \(context) —————————————————————")
        for (i,s) in musicPlayerQueue.enumerated() {
            let mark = i == nowPlayingIndex ? "▶︎" : " "
            print("\(mark)[\(i)] \(s.title) — \(s.artistName)")
        }
        print("History → \(history.map{ $0.title })")
    }

    private func handleQueueAction(_ action: QueueUpdateAction) async {
        switch action {
            case .playNewQueue:
                if let descriptor = try? MusicPlayerUtils.buildQueueDescriptor(from: await queueManager.items, startAt: queueManager.currentIndex) {
                    playerAdapter.setQueue(with: descriptor)
                    playerAdapter.play()
                    playerAdapter.playbackRate = currentPlaybackRate
                } else {
                    playerAdapter.stop()
                }
            case .updatePlayerQueueOnly:
            if let descriptor = try? MusicPlayerUtils.buildQueueDescriptor(from: await queueManager.items, startAt: queueManager.currentIndex) {

                let currentPos = playerAdapter.currentTime
                playerAdapter.setQueue(with: descriptor)
                playerAdapter.seek(to: currentPos)
                
                playerAdapter.playbackRate = currentPlaybackRate
            }
            case .playCurrentTrack:
                playerAdapter.play()
            case .playerShouldStop:
                playerAdapter.stop()
            case .noAction:
                break
        }
    }
}
