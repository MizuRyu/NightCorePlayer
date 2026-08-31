import Combine
import MediaPlayer
import MusicKit
import Foundation
import AVFoundation
import os
import NightCoreDomain

@MainActor
public final class MusicPlayerServiceImpl: MusicPlayerService {
    private let logger = Logger(subsystem: Constants.Logging.subsystem, category: "MusicPlayer")
    @Published public private(set) var snapshot: MusicPlayerSnapshot = .empty
    @Published public private(set) var isShuffled: Bool = false
    @Published public private(set) var repeatMode: Constants.RepeatMode = .none
    @Published public private(set) var isAutoPlayEnabled: Bool = false

    private var originalQueue: [Song] = []
    private var lastSnapshotSongID: String?
    private let playbackErrorSubject = PassthroughSubject<Error, Never>()

    public var snapshotPublisher: AnyPublisher<MusicPlayerSnapshot, Never> {
        $snapshot.eraseToAnyPublisher()
    }

    public var playbackErrorPublisher: AnyPublisher<Error, Never> {
        playbackErrorSubject.eraseToAnyPublisher()
    }

    public var musicPlayerQueue: [Song] { queue.items }
    public var nowPlayingIndex: Int { queue.currentIndex }

    private var player: PlayerControllable
    public var queue: QueueManaging

    private let rateManager: PlaybackRateManager
    private let persistenceService: PlayerPersistenceService
    private let historyManager: PlayHistoryManaging
    private let artworkService: ArtworkCacheService
    private let musicKitService: MusicKitService?
    private let allowanceEnforcer: AllowanceEnforcer?
    private let now: () -> Date

    var currentPlaybackRate: Double = Constants.MusicPlayer.defaultPlaybackRate
    /// 残高枯渇の曲境界停止時に保持する停止前の倍速。リワード付与後の自動復帰に使う (#87)
    private var rateBeforeAllowanceStop: Double?
    private let minPlaybackRate: Double = Constants.MusicPlayer.minPlaybackRate
    private let maxPlaybackRate: Double = Constants.MusicPlayer.maxPlaybackRate

    private var timerCancellable: AnyCancellable?
    private var lastPlayerIndex: Int?
    private var pendingNativeNowPlayingIndex: Int?
    private var pendingShuffleResync: Bool = false
    private var needsQueueRefresh: Bool = false
    private var isFetchingRecommendations: Bool = false
    private var hasStarted: Bool = false

    init(
        rateManager: PlaybackRateManager,
        persistenceService: PlayerPersistenceService,
        historyManager: PlayHistoryManaging,
        artworkService: ArtworkCacheService,
        musicKitService: MusicKitService? = nil,
        playerAdapter: PlayerControllable? = nil,
        queueManager: QueueManaging? = nil,
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

        self.player   = playerAdapter ?? MPMusicPlayerAdapter(defaultRate: rateManager.defaultRate)
        self.queue    = queueManager ?? MusicQueueManager()

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
            let userInfo   = notification.userInfo,
            let reasonRaw  = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason     = AVAudioSession.RouteChangeReason(rawValue: reasonRaw),
            reason == .oldDeviceUnavailable,
            let prevRoute  = userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription
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

    @objc private func handlePlaybackStateChange(_ notification: Notification) {
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

        if repeatMode == .all && !queue.isEmpty {
            queue.currentIndex = 0
            await handleQueueAction(.playNewQueue)
            return
        }

        if isAutoPlayEnabled && repeatMode == .none {
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
        let t   = Swift.min(Swift.max(time, 0), dur)
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

    public var playHistory: [Song] { historyManager.history }

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
        case .all:  next = .one
        case .one:  next = .none
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

    // MARK: - Auto-Play Recommendations

    private func fetchAndPlayRecommendations() async {
        guard let musicKitService, !isFetchingRecommendations else { return }
        isFetchingRecommendations = true
        defer { isFetchingRecommendations = false }

        do {
            // 履歴曲は除外しない: レコメンドの C 枠 (よく聴く曲) は履歴由来が本体のため。
            // キューに既にある曲だけ重複を避ける
            let existingIDs = Set(queue.items.map { $0.id })

            let recommendations = try await musicKitService.fetchPersonalRecommendations(
                history: historyManager.history,
                limit: Constants.Recommendation.defaultLimit
            )
            let filtered = recommendations.filter { !existingIDs.contains($0.id) }
            guard !filtered.isEmpty else { return }

            // 現在のキューに推薦楽曲を追加して再生
            var newQueue = queue.items
            newQueue.append(contentsOf: filtered)
            let nextIndex = queue.currentIndex + 1
            let action = await queue.setQueue(newQueue, startAt: nextIndex)
            await handleQueueAction(action)
        } catch {
            logger.error("Auto-play recommendation fetch error: \(error.localizedDescription)")
        }
    }

    private func checkAutoPlayOnQueueEnd() {
        guard isAutoPlayEnabled,
              repeatMode == .none,
              !queue.isEmpty,
              queue.currentIndex >= queue.items.count - 1,
              player.playbackState != .playing
        else { return }

        Task { [weak self] in
            await self?.fetchAndPlayRecommendations()
        }
    }

    // MARK: - Private

    private func handleQueueAction(_ action: QueueUpdateAction, autoPlay: Bool = true) async {
        switch action {
        case .playNewQueue:
            await syncPlayerQueue(autoPlay: autoPlay, preserveCurrentTime: false)
            updateSnapshot()
        case .updatePlayerQueueOnly:
            await syncPlayerQueue(
                autoPlay: player.playbackState == .playing,
                preserveCurrentTime: true
            )
            updateSnapshot()
        case .playerShouldStop:
            player.stop()
            updateSnapshot()
        case .noAction:
            break
        }
    }

    private func updateSnapshot() {
        let item = player.nowPlayingItem
        let song = queue.currentSong
        let timestamp = now()

        allowanceEnforcer?.tick(
            isPlaying: player.playbackState == .playing,
            rate: currentPlaybackRate,
            songID: song?.id.rawValue,
            now: timestamp
        )

        // 猶予対象外の曲での倍速は曲末を待たず等速へ戻す（等速再生自体は止めない）
        revertToNormalRateIfNeeded()

        let title = song?.title ?? item?.title ?? "-"
        let artist = song?.artistName ?? item?.artist ?? "-"
        let duration = song?.duration ?? item?.playbackDuration ?? 0
        let currentTime = player.currentTime

        guard let song = song else {
            snapshot = MusicPlayerSnapshot.empty
            return
        }

        let currentID = song.id.rawValue
        let isNewSong = (lastSnapshotSongID != currentID)

        // MPMusicPlayerController.pause() の playbackState 反映は非同期のため、
        // 停止ブロック内で明示的に書き換えられるよう先に読んでおく
        var isPlaying = player.playbackState == .playing
        let rate = currentPlaybackRate

        // 残高枯渇時は現在の曲の末尾まで再生し、曲替わりのタイミングで停止する（ブツ切り防止）
        if isNewSong, stopAtSongBoundaryIfNeeded(pausePlayer: true) {
            isPlaying = false
        }

        if isNewSong {
            lastSnapshotSongID = currentID
        }

        let existingArtwork = snapshot.artworkData

        snapshot = MusicPlayerSnapshot(
            title: title,
            artist: artist,
            artworkData: existingArtwork,
            currentTime: currentTime,
            duration: duration,
            rate: rate,
            isPlaying: isPlaying
        )

        guard isNewSong else { return }

        if let newSong = queue.currentSong {
            do {
                try historyManager.append(newSong)
            } catch {
                logger.error("History append error: \(error.localizedDescription)")
            }
        }
        saveState()

        Task { [weak self] in
            guard let self = self else { return }
            let fetchedData = await self.artworkService.getArtwork(for: song)
            // 取得完了時点のライブ値で再構築し、古い再生状態（rate/isPlaying）を再配信しない
            let updated = MusicPlayerSnapshot(
                title: title,
                artist: artist,
                artworkData: fetchedData,
                currentTime: self.player.currentTime,
                duration: duration,
                rate: self.currentPlaybackRate,
                isPlaying: self.player.playbackState == .playing
            )
            self.snapshot = updated
        }
    }

    private func applyRepeatModeToPlayer() {
        switch repeatMode {
        case .none:
            player.repeatMode = .none
        case .all:
            player.repeatMode = .all
        case .one:
            player.repeatMode = .one
        }
    }

    private func trackChanged() {
        let playerIndex = player.indexOfNowPlayingItem

        if let pendingIndex = pendingNativeNowPlayingIndex {
            pendingNativeNowPlayingIndex = nil
            lastPlayerIndex = playerIndex
            if queue.items.indices.contains(pendingIndex) {
                queue.currentIndex = pendingIndex
            }
            updateSnapshot()
            return
        }

        if needsQueueRefresh {
            needsQueueRefresh = false
            Task { [weak self] in
                await self?.handleQueueAction(.updatePlayerQueueOnly)
            }
        }

        // 明示的なキュー更新直後（next/previous/setQueue経由）は
        // lastPlayerIndex が nil にリセットされている。
        // currentIndex は既に正しいので、ベースラインだけ記録して終了。
        if lastPlayerIndex == nil {
            lastPlayerIndex = playerIndex
            updateSnapshot()
            return
        }

        guard playerIndex != lastPlayerIndex else { return }

        let previousPlayerIndex = lastPlayerIndex!
        lastPlayerIndex = playerIndex

        guard playerIndex >= 0, !queue.items.isEmpty else {
            updateSnapshot()
            return
        }

        // nowPlayingItem の ID で内部キューを照合（シャッフル時も正確）
        if let nowPlaying = player.nowPlayingItem,
           let persistentID = nowPlaying.value(forProperty: MPMediaItemPropertyPersistentID) as? UInt64 {
            let idString = String(persistentID)
            if let matchIndex = queue.items.firstIndex(where: { $0.id.rawValue == idString }) {
                queue.currentIndex = matchIndex
                updateSnapshot()
                return
            }
        }

        // ID 照合できない場合は delta ベースのフォールバック
        let delta = playerIndex - previousPlayerIndex
        let newIndex = queue.currentIndex + delta

        if newIndex >= 0 && newIndex < queue.items.count {
            queue.currentIndex = newIndex
        } else if newIndex < 0 {
            let baseIndex = queue.currentIndex - previousPlayerIndex
            let wrapped = max(baseIndex + playerIndex, 0)
            queue.currentIndex = min(wrapped, queue.items.count - 1)
        } else {
            queue.currentIndex = queue.items.count - 1
        }

        updateSnapshot()
    }

    private func makePlayParameters(for song: Song) throws -> MPMusicPlayerPlayParameters? {
        guard let playParams = song.playParameters else {
            return nil
        }
        let data = try JSONEncoder().encode(playParams)
        let pp   = try JSONDecoder().decode(MPMusicPlayerPlayParameters.self, from: data)
        return pp
    }

    private func buildQueueDescriptor(from songs: [Song], startAt index: Int) throws -> MPMusicPlayerPlayParametersQueueDescriptor {
        guard !songs.isEmpty, songs.indices.contains(index) else {
            throw NSError(domain: "MusicPlayerUtils", code: -2, userInfo: nil)
        }
        let target: [Song]
        if repeatMode == .one {
            target = [songs[index]]
        } else if repeatMode == .all {
            target = Array(songs[index...]) + Array(songs[..<index])
        } else {
            target = Array(songs[index...])
        }
        let params = try target.compactMap { try makePlayParameters(for: $0) }
        guard !params.isEmpty else {
            throw NSError(domain: "MusicPlayerUtils", code: -2, userInfo: nil)
        }
        return MPMusicPlayerPlayParametersQueueDescriptor(playParametersQueue: params)
    }

    private func syncPlayerQueue(autoPlay: Bool, preserveCurrentTime: Bool) async {
        lastPlayerIndex = nil
        pendingNativeNowPlayingIndex = nil
        pendingShuffleResync = false

        guard let descriptor = try? buildQueueDescriptor(from: queue.items, startAt: queue.currentIndex) else {
            player.stop()
            return
        }

        let currentPos = preserveCurrentTime ? player.currentTime : 0
        player.setQueue(with: descriptor)
        if autoPlay {
            do {
                try await player.prepareToPlay()
            } catch {
                #if DEBUG
                logger.error("prepareToPlay failed: \(error.localizedDescription)")
                #endif
                playbackErrorSubject.send(error)
                return
            }
            if preserveCurrentTime {
                player.seek(to: currentPos)
            }
            player.play()
        } else if preserveCurrentTime {
            player.seek(to: currentPos)
        }
        applyRepeatModeToPlayer()
        player.playbackRate = currentPlaybackRate
    }

    private func restore() async {
        // #69 で構造体化するまでの暫定
        // swiftlint:disable:next large_tuple
        let st: (queueIDs: [String], currentIndex: Int, playbackRate: Double, shuffleModeRaw: Int, repeatModeRaw: Int, isAutoPlayEnabled: Bool)
        do {
            st = try persistenceService.loadState()
        } catch {
            st = ([], 0, Constants.MusicPlayer.defaultPlaybackRate,
                  MPMusicShuffleMode.off.rawValue, MPMusicRepeatMode.none.rawValue, false)
        }

        let restoredRepeat = MPMusicRepeatMode(rawValue: st.repeatModeRaw) ?? .none
        isShuffled = st.shuffleModeRaw != Int(MPMusicShuffleMode.off.rawValue)
        switch restoredRepeat {
        case .all:  repeatMode = .all
        case .one:  repeatMode = .one
        default:    repeatMode = .none
        }
        isAutoPlayEnabled = st.isAutoPlayEnabled

        do {
            let songs = try await persistenceService.fetchCatalogSongs(st.queueIDs)
            await self.setQueue(songs: songs, startAt: st.currentIndex, autoPlay: false)
        } catch {
            await self.setQueue(songs: [], startAt: 0, autoPlay: false)
        }

        let historyIDs: [String]
        do {
            historyIDs = try persistenceService.loadHistoryIDs()
        } catch {
            historyIDs = []
        }
        do {
            let historySongs = try await persistenceService.fetchCatalogSongs(historyIDs)
            historyManager.restoreHistory(historySongs)
        } catch {
            historyManager.restoreHistory([])
        }

        currentPlaybackRate = rateManager.defaultRate
        player.playbackRate = rateManager.defaultRate
        player.shuffleMode  = .off  // アプリ側シャッフルのため常にoff
        applyRepeatModeToPlayer()
    }

    private func saveState() {
        let shuffleModeRaw: Int = isShuffled
            ? Int(MPMusicShuffleMode.songs.rawValue)
            : Int(MPMusicShuffleMode.off.rawValue)

        let repeatModeRaw: Int
        switch repeatMode {
        case .all:  repeatModeRaw = Int(MPMusicRepeatMode.all.rawValue)
        case .one:  repeatModeRaw = Int(MPMusicRepeatMode.one.rawValue)
        case .none: repeatModeRaw = Int(MPMusicRepeatMode.none.rawValue)
        }

        do {
            try persistenceService.saveQueueState(
                queueIDs: queue.items.map { $0.id.rawValue },
                currentIndex: queue.currentIndex,
                playbackRate: rateManager.defaultRate,
                shuffleModeRaw: shuffleModeRaw,
                repeatModeRaw: repeatModeRaw,
                isAutoPlayEnabled: isAutoPlayEnabled
            )
        } catch {
            logger.error("State save error: \(error.localizedDescription)")
        }
    }
}

extension MusicPlayerServiceImpl {
    public func resumeAfterRewardGrant() async {
        guard let savedRate = rateBeforeAllowanceStop else { return }
        rateBeforeAllowanceStop = nil
        // ユーザーが既に手動で再生を再開していたら、倍速だけ勝手に変えない
        guard player.playbackState != .playing else { return }
        currentPlaybackRate = savedRate
        await play()
    }
}

private extension MusicPlayerServiceImpl {
    /// 猶予を使い切った後の曲で倍速に入られた場合、曲末を待たず等速へ戻す。
    /// 曲末停止は「残高が尽きた時点で鳴っていた曲」だけの猶予であり、別の曲には及ばない
    func revertToNormalRateIfNeeded() {
        guard let enforcer = allowanceEnforcer, enforcer.shouldRevertToNormalRateNow() else { return }
        rateBeforeAllowanceStop = currentPlaybackRate
        currentPlaybackRate = Constants.MusicPlayer.normalPlaybackRate
        player.playbackRate = currentPlaybackRate
        enforcer.markRevertedToNormalRate()
    }

    /// 枯渇時は曲境界でのみ停止する。素の（等速）再生は制限しない
    func stopAtSongBoundaryIfNeeded(pausePlayer: Bool) -> Bool {
        guard let enforcer = allowanceEnforcer, enforcer.shouldStopAtSongBoundary() else { return false }
        if pausePlayer {
            player.pause()
        }
        rateBeforeAllowanceStop = currentPlaybackRate
        currentPlaybackRate = Constants.MusicPlayer.normalPlaybackRate
        player.playbackRate = currentPlaybackRate
        enforcer.markStoppedAtSongEnd()
        return true
    }
}
