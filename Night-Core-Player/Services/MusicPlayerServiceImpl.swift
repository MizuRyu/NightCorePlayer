import AVFoundation
import Combine
import Foundation
import MediaPlayer
import MusicKit
import NightCoreDomain
import os

@MainActor
public final class MusicPlayerServiceImpl: MusicPlayerService {
    // 実装は MusicPlayerServiceImpl+*.swift の extension に分かれている。
    // Swift の private はファイル単位のため、それらから触る状態は internal に留める
    let logger = Logger(subsystem: Constants.Logging.subsystem, category: "MusicPlayer")
    @Published public internal(set) var snapshot: MusicPlayerSnapshot = .empty
    @Published public internal(set) var isShuffled: Bool = false
    @Published public internal(set) var repeatMode: Constants.RepeatMode = .none
    @Published public internal(set) var isAutoPlayEnabled: Bool = false

    private var originalQueue: [Song] = []
    var lastSnapshotSongID: String?
    let playbackErrorSubject = PassthroughSubject<Error, Never>()

    public var snapshotPublisher: AnyPublisher<MusicPlayerSnapshot, Never> {
        $snapshot.eraseToAnyPublisher()
    }

    public var playbackErrorPublisher: AnyPublisher<Error, Never> {
        playbackErrorSubject.eraseToAnyPublisher()
    }

    public var musicPlayerQueue: [Song] {
        queue.items
    }

    public var nowPlayingIndex: Int {
        queue.currentIndex
    }

    var player: PlayerControllable
    public var queue: any QueueManaging<Song>

    let rateManager: PlaybackRateManager
    let persistenceService: PlayerPersistenceService
    let historyManager: any PlayHistoryManaging<Song>
    let artworkService: ArtworkCacheService
    let musicKitService: MusicKitService?
    let allowanceEnforcer: AllowanceEnforcer?
    let now: () -> Date

    var currentPlaybackRate: Double = Constants.MusicPlayer.defaultPlaybackRate
    /// 残高枯渇の曲境界停止時に保持する停止前の倍速。リワード付与後の自動復帰に使う (#87)
    var rateBeforeAllowanceStop: Double?
    private let minPlaybackRate: Double = Constants.MusicPlayer.minPlaybackRate
    private let maxPlaybackRate: Double = Constants.MusicPlayer.maxPlaybackRate

    private var timerCancellable: AnyCancellable?
    var lastPlayerIndex: Int?
    var pendingNativeNowPlayingIndex: Int?
    var pendingShuffleResync: Bool = false
    var needsQueueRefresh: Bool = false
    var isFetchingRecommendations: Bool = false
    private var hasStarted: Bool = false

    init(
        rateManager: PlaybackRateManager,
        persistenceService: PlayerPersistenceService,
        historyManager: any PlayHistoryManaging<Song>,
        artworkService: ArtworkCacheService,
        musicKitService: MusicKitService? = nil,
        playerAdapter: PlayerControllable? = nil,
        queueManager: (any QueueManaging<Song>)? = nil,
        allowanceEnforcer: AllowanceEnforcer? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.rateManager = rateManager
        self.persistenceService = persistenceService
        self.historyManager = historyManager
        self.artworkService = artworkService
        self.musicKitService = musicKitService
        self.allowanceEnforcer = allowanceEnforcer
        self.now = now

        self.player = playerAdapter ?? MPMusicPlayerAdapter(defaultRate: rateManager.defaultRate)
        self.queue = queueManager ?? MusicQueueManager<Song>()

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            logger.error("AVAudioSession error: \(error)")
        }

        timerCancellable = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.updateSnapshot() }

        NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.trackChanged() }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePlaybackStateChange(_:)),
            name: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: nil
        )
    }

    deinit {
        timerCancellable?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleAudioRouteChange(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let reasonRaw = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue: reasonRaw),
            reason == .oldDeviceUnavailable,
            let prevRoute = userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription
        else { return }

        let wiredPorts: [AVAudioSession.Port] = [
            .headphones,
            .headsetMic,
            .lineOut
        ]
        let wasWired = prevRoute.outputs.contains { wiredPorts.contains($0.portType) }
        guard wasWired else { return }

        Task { [weak self] in await self?.pause() }
    }

    @objc private func handlePlaybackStateChange(_: Notification) {
        if player.playbackState == .playing {
            player.playbackRate = currentPlaybackRate
            return
        }

        if player.playbackState == .stopped {
            if repeatMode == .one, queue.currentSong != nil {
                // 残高枯渇時はrepeat .oneの無限ループを抜けられないため、停止予約があればループ再生せず止める
                if stopAtSongBoundaryIfNeeded(pausePlayer: false) {
                    updateSnapshot()
                    return
                }
                player.seek(to: 0)
                player.play()
                player.playbackRate = currentPlaybackRate
                updateSnapshot()
                return
            }
            // キュー末尾で停止した場合のみ自動再生をチェック（一時停止では発火しない）
            checkAutoPlayOnQueueEnd()
        }
    }

    // MARK: - Playback Controls

    public func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        await restore()
        updateSnapshot()
    }

    public func setQueue(songs: [Song], startAt idx: Int, autoPlay: Bool = true) async {
        let action = await queue.setQueue(songs, startAt: idx)
        await handleQueueAction(action, autoPlay: autoPlay)
    }

    public func play() async {
        player.play()
        player.playbackRate = currentPlaybackRate
        updateSnapshot()
    }

    public func pause() async {
        player.pause()
        updateSnapshot()
    }

    public func next() async {
        if repeatMode == .one {
            let advanced = await queue.advanceToNextTrack()
            guard advanced else { return }
            await handleQueueAction(.playNewQueue)
            return
        }

        if queue.currentIndex + 1 < queue.items.count {
            if pendingShuffleResync {
                queue.currentIndex += 1
                await handleQueueAction(.playNewQueue)
                return
            }
            pendingNativeNowPlayingIndex = queue.currentIndex + 1
            player.skipToNext()
            return
        }

        if repeatMode == .all, !queue.isEmpty {
            queue.currentIndex = 0
            await handleQueueAction(.playNewQueue)
            return
        }

        if isAutoPlayEnabled, repeatMode == .none {
            await fetchAndPlayRecommendations()
        }
    }

    public func previous() async {
        if repeatMode == .one {
            let regressed = await queue.regressToPreviousTrack()
            guard regressed else { return }
            await handleQueueAction(.playNewQueue)
            return
        }

        guard queue.currentIndex > 0 else { return }
        if pendingShuffleResync {
            queue.currentIndex -= 1
            await handleQueueAction(.playNewQueue)
            return
        }
        pendingNativeNowPlayingIndex = queue.currentIndex - 1
        player.skipToPrevious()
    }

    public func seek(to time: TimeInterval) async {
        let dur = queue.currentSong?.duration ?? player.nowPlayingItem?.playbackDuration ?? 0
        let t = Swift.min(Swift.max(time, 0), dur)
        player.seek(to: t)
        updateSnapshot()
    }

    public func setSessionRate(_ rate: Double) async {
        // 手動で倍速を変えたら、境界停止からの自動復帰情報は陳腐化する
        rateBeforeAllowanceStop = nil
        currentPlaybackRate = Swift.min(Swift.max(rate, minPlaybackRate), maxPlaybackRate)
        player.playbackRate = currentPlaybackRate
        updateSnapshot()
    }

    // MARK: - Queue Operations

    public func moveItem(from src: Int, to dst: Int) async {
        let action = await queue.moveItem(from: src, to: dst)
        if action == .updatePlayerQueueOnly {
            // 再生中はキュー再構築を遅延して音途切れを防ぐ
            pendingShuffleResync = true
        }
        updateSnapshot()
    }

    public func removeItem(at idx: Int) async {
        let (action, _) = await queue.removeItem(at: idx)
        switch action {
        case .playNewQueue, .playerShouldStop:
            await handleQueueAction(action)
        case .updatePlayerQueueOnly:
            needsQueueRefresh = true
            updateSnapshot()
        case .noAction:
            break
        }
    }

    public func playNow(_ song: Song) async {
        let action = await queue.setQueue([song], startAt: 0)
        await handleQueueAction(action)
    }

    public func insertNext(_ song: Song) async {
        let (action, _) = await queue.insertNext(song)
        if action == .playNewQueue {
            await handleQueueAction(action)
            return
        }
        if let pp = try? makePlayParameters(for: song) {
            player.prepend(MPMusicPlayerPlayParametersQueueDescriptor(playParametersQueue: [pp]))
        }
    }

    public func playNextAndPlay(_ song: Song) async {
        var items = queue.items
        if let oldIdx = items.firstIndex(where: { $0.id == song.id }) {
            items.remove(at: oldIdx)
        }

        let insertionIndex = min(queue.currentIndex + 1, items.count)
        items.insert(song, at: insertionIndex)

        let action = await queue.setQueue(items, startAt: insertionIndex)
        await handleQueueAction(action)
    }

    // MARK: - History

    public var playHistory: [Song] {
        historyManager.history
    }

    public func clearHistory() throws {
        try historyManager.clearHistory()
    }

    // MARK: - Shuffle / Repeat

    public func toggleShuffle() async {
        let shouldResumePlayback = player.playbackState == .playing
        if isShuffled {
            guard !originalQueue.isEmpty else {
                isShuffled = false
                player.shuffleMode = .off
                saveState()
                updateSnapshot()
                return
            }
            let currentSong = queue.currentSong
            let restoredItems = originalQueue
            originalQueue = []

            if let song = currentSong,
               let idx = restoredItems.firstIndex(where: { $0.id == song.id }) {
                _ = await queue.setQueue(restoredItems, startAt: idx)
            } else {
                _ = await queue.setQueue(restoredItems, startAt: 0)
            }
            isShuffled = false
        } else {
            guard !queue.items.isEmpty else {
                isShuffled = true
                saveState()
                updateSnapshot()
                return
            }
            originalQueue = queue.items
            let currentSong = queue.currentSong
            var remaining = queue.items
            if let song = currentSong,
               let idx = remaining.firstIndex(where: { $0.id == song.id }) {
                remaining.remove(at: idx)
                remaining.shuffle()
                remaining.insert(song, at: 0)
            } else {
                remaining.shuffle()
            }
            _ = await queue.setQueue(remaining, startAt: 0)
            isShuffled = true
        }
        player.shuffleMode = .off
        if shouldResumePlayback {
            pendingShuffleResync = true
            saveState()
            updateSnapshot()
            return
        }
        await syncPlayerQueue(autoPlay: shouldResumePlayback, preserveCurrentTime: true)
        saveState()
        updateSnapshot()
    }

    public func cycleRepeatMode() async {
        let next: Constants.RepeatMode
        switch repeatMode {
        case .none: next = .all
        case .all: next = .one
        case .one: next = .none
        }
        repeatMode = next

        applyRepeatModeToPlayer()
        saveState()
        updateSnapshot()
    }

    public func toggleAutoPlay() async {
        isAutoPlayEnabled.toggle()
        saveState()
    }
}
