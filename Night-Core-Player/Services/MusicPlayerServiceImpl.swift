import Combine
import MediaPlayer
import MusicKit
import Foundation
import AVFoundation

@MainActor
public final class MusicPlayerServiceImpl: MusicPlayerService {
    @Published public private(set) var snapshot: MusicPlayerSnapshot = .empty
    @Published public private(set) var isShuffled: Bool = false
    @Published public private(set) var repeatMode: Constants.RepeatMode = .none
    @Published public private(set) var isAutoPlayEnabled: Bool = false

    private var originalQueue: [Song] = []

    public var snapshotPublisher: AnyPublisher<MusicPlayerSnapshot, Never> {
        $snapshot.eraseToAnyPublisher()
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

    var currentPlaybackRate: Double = Constants.MusicPlayer.defaultPlaybackRate
    private let minPlaybackRate: Double = Constants.MusicPlayer.minPlaybackRate
    private let maxPlaybackRate: Double = Constants.MusicPlayer.maxPlaybackRate

    private var timerCancellable: AnyCancellable?
    private var lastPlayerIndex: Int? = nil
    private var needsQueueRefresh: Bool = false
    private var isFetchingRecommendations: Bool = false

    init(
        rateManager: PlaybackRateManager,
        persistenceService: PlayerPersistenceService,
        historyManager: PlayHistoryManaging,
        artworkService: ArtworkCacheService,
        musicKitService: MusicKitService? = nil,
        playerAdapter : PlayerControllable? = nil,
        queueManager : QueueManaging? = nil
    ) {
        self.rateManager = rateManager
        self.persistenceService = persistenceService
        self.historyManager = historyManager
        self.artworkService = artworkService
        self.musicKitService = musicKitService

        self.player   = playerAdapter ?? MPMusicPlayerAdapter(defaultRate: rateManager.defaultRate)
        self.queue    = queueManager ?? MusicQueueManager()

        Task { await self.restore() }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("AVAudioSession error: \(error)")
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
        }
        // キュー末尾で停止した場合、自動再生をチェック
        if player.playbackState == .stopped || player.playbackState == .paused {
            checkAutoPlayOnQueueEnd()
        }
    }

    // MARK: - Playback Controls

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
        let advanced = await queue.advanceToNextTrack()
        if advanced {
            await handleQueueAction(.playNewQueue)
            return
        }
        // キュー末尾で自動再生が有効なら推薦楽曲を取得して再生
        if isAutoPlayEnabled && repeatMode == .none {
            await fetchAndPlayRecommendations()
        }
    }

    public func previous() async {
        let regressed = await queue.regressToPreviousTrack()
        guard regressed else { return }
        await handleQueueAction(.playNewQueue)
    }

    public func seek(to time: TimeInterval) async {
        let dur = queue.currentSong?.duration ?? player.nowPlayingItem?.playbackDuration ?? 0
        let t   = Swift.min(Swift.max(time, 0), dur)
        player.seek(to: t)
        updateSnapshot()
    }

    public func setSessionRate(_ rate: Double) async {
        currentPlaybackRate = Swift.min(Swift.max(rate, minPlaybackRate), maxPlaybackRate)
        player.playbackRate = currentPlaybackRate
        updateSnapshot()
    }

    // MARK: - Queue Operations

    public func moveItem(from src: Int, to dst: Int) async {
        let _ = await queue.moveItem(from: src, to: dst)
        needsQueueRefresh = true
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
        if isShuffled {
            // シャッフル OFF: 元の順序に復元
            guard !originalQueue.isEmpty else {
                isShuffled = false
                player.shuffleMode = .off
                updateSnapshot()
                return
            }
            let currentSong = queue.currentSong
            let restoredItems = originalQueue
            originalQueue = []

            if let song = currentSong,
               let idx = restoredItems.firstIndex(where: { $0.id == song.id }) {
                let _ = await queue.setQueue(restoredItems, startAt: idx)
                await handleQueueAction(.updatePlayerQueueOnly)
            } else {
                let _ = await queue.setQueue(restoredItems, startAt: 0)
                await handleQueueAction(.playNewQueue)
            }
            isShuffled = false
        } else {
            // シャッフル ON: 現在のキューを保存してシャッフル
            guard !queue.items.isEmpty else {
                isShuffled = true
                updateSnapshot()
                return
            }
            originalQueue = queue.items
            let currentSong = queue.currentSong
            var remaining = queue.items
            // 現在の曲を除外してシャッフルし、先頭に再配置
            if let song = currentSong,
               let idx = remaining.firstIndex(where: { $0.id == song.id }) {
                remaining.remove(at: idx)
                remaining.shuffle()
                remaining.insert(song, at: 0)
            } else {
                remaining.shuffle()
            }
            let _ = await queue.setQueue(remaining, startAt: 0)
            await handleQueueAction(.updatePlayerQueueOnly)
            isShuffled = true
        }
        player.shuffleMode = .off
        updateSnapshot()
    }

    public func cycleRepeatMode() async {
        let next: MPMusicRepeatMode
        switch player.repeatMode {
        case .none: next = .all
        case .all:  next = .one
        case .one:  next = .none
        case .default: next = .none
        @unknown default: next = .none
        }
        player.repeatMode = next

        switch next {
        case .none: repeatMode = .none
        case .all:  repeatMode = .all
        case .one:  repeatMode = .one
        case .default: repeatMode = .none
        @unknown default: repeatMode = .none
        }
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
            let existingIDs = Set(queue.items.map { $0.id })
            let historyIDs = Set(historyManager.history.map { $0.id })
            let excludeIDs = existingIDs.union(historyIDs)

            let recommendations = try await musicKitService.fetchPersonalRecommendations(
                limit: Constants.Recommendation.defaultLimit
            )
            let filtered = recommendations.filter { !excludeIDs.contains($0.id) }
            guard !filtered.isEmpty else { return }

            // 現在のキューに推薦楽曲を追加して再生
            var newQueue = queue.items
            newQueue.append(contentsOf: filtered)
            let nextIndex = queue.currentIndex + 1
            let action = await queue.setQueue(newQueue, startAt: nextIndex)
            await handleQueueAction(action)
        } catch {
            print("⚠️ Auto-play recommendation fetch error: \(error.localizedDescription)")
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
            lastPlayerIndex = nil
            if let descriptor = try? buildQueueDescriptor(from: await queue.items, startAt: queue.currentIndex) {
                player.setQueue(with: descriptor)
                if autoPlay {
                    player.play()
                }
                player.playbackRate = currentPlaybackRate
            } else {
                player.stop()
            }
            updateSnapshot()
        case .updatePlayerQueueOnly:
            lastPlayerIndex = nil
            if let descriptor = try? buildQueueDescriptor(from: await queue.items, startAt: queue.currentIndex) {
                let currentPos = player.currentTime
                player.setQueue(with: descriptor)
                player.seek(to: currentPos)
                player.playbackRate = currentPlaybackRate
            }
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
        let title = song?.title ?? item?.title ?? "-"
        let artist = song?.artistName ?? item?.artist ?? "-"
        let duration = song?.duration ?? item?.playbackDuration ?? 0
        let currentTime = player.currentTime
        let isPlaying = player.playbackState == .playing
        let rate = currentPlaybackRate

        guard let song = song else {
            snapshot = MusicPlayerSnapshot.empty
            return
        }

        struct Holder { static var lastSongID: String? = nil }
        let currentID = song.id.rawValue
        let isNewSong = (Holder.lastSongID != currentID)
        if isNewSong {
            Holder.lastSongID = currentID
        }

        let existingArtwork = snapshot.artworkData

        snapshot = MusicPlayerSnapshot(
            title:       title,
            artist:      artist,
            artworkData: existingArtwork,
            currentTime: currentTime,
            duration:    duration,
            rate:        rate,
            isPlaying:   isPlaying
        )

        guard isNewSong else { return }

        if let newSong = queue.currentSong {
            do {
                try historyManager.append(newSong)
            } catch {
                print("⚠️ History append error: \(error.localizedDescription)")
            }
        }
        do {
            try persistenceService.saveQueueState(
                queueIDs:      queue.items.map { $0.id.rawValue },
                currentIndex:  queue.currentIndex,
                playbackRate:  rateManager.defaultRate,
                shuffleModeRaw: Int(player.shuffleMode.rawValue),
                repeatModeRaw:  Int(player.repeatMode.rawValue),
                isAutoPlayEnabled: isAutoPlayEnabled
            )
        } catch {
            print("⚠️ Queue state save error: \(error.localizedDescription)")
        }

        Task { [weak self] in
            guard let self = self else { return }
            let fetchedData = await self.artworkService.getArtwork(for: song)
            let updated = MusicPlayerSnapshot(
                title:       title,
                artist:      artist,
                artworkData: fetchedData,
                currentTime: currentTime,
                duration:    duration,
                rate:        rate,
                isPlaying:   isPlaying
            )
            self.snapshot = updated
        }
    }

    private func trackChanged() {
        let playerIndex = player.indexOfNowPlayingItem

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

        // 非ローテーション descriptor では player index の delta が
        // そのまま queue.currentIndex の delta に対応する。
        let delta = playerIndex - previousPlayerIndex
        let newIndex = queue.currentIndex + delta

        if newIndex >= 0 && newIndex < queue.items.count {
            queue.currentIndex = newIndex
        } else if newIndex < 0 {
            // repeat all でラップアラウンド: descriptor 先頭に戻る
            // descriptor は queue.items[descriptorStart...] なので先頭は不明だが、
            // playerIndex=0 は「descriptor 構築時の currentIndex」に対応。
            // 現時点の currentIndex - previousPlayerIndex でベースを推定。
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
        let remaining = Array(songs[index...])
        let params = try remaining.compactMap { try makePlayParameters(for: $0) }
        guard !params.isEmpty else {
            throw NSError(domain: "MusicPlayerUtils", code: -2, userInfo: nil)
        }
        return MPMusicPlayerPlayParametersQueueDescriptor(playParametersQueue: params)
    }

    private func restore() async {
        let st: (queueIDs: [String], currentIndex: Int, playbackRate: Double, shuffleModeRaw: Int, repeatModeRaw: Int, isAutoPlayEnabled: Bool)
        do {
            st = try persistenceService.loadState()
        } catch {
            st = ([], 0, Constants.MusicPlayer.defaultPlaybackRate,
                  MPMusicShuffleMode.off.rawValue, MPMusicRepeatMode.none.rawValue, false)
        }

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
        player.shuffleMode  = MPMusicShuffleMode(rawValue: st.shuffleModeRaw) ?? .off
        player.repeatMode   = MPMusicRepeatMode(rawValue: st.repeatModeRaw)  ?? .none
        isShuffled = player.shuffleMode != .off
        isAutoPlayEnabled = st.isAutoPlayEnabled
    }

    private func saveState() {
        do {
            try persistenceService.saveQueueState(
                queueIDs:      queue.items.map { $0.id.rawValue },
                currentIndex:  queue.currentIndex,
                playbackRate:  rateManager.defaultRate,
                shuffleModeRaw: Int(player.shuffleMode.rawValue),
                repeatModeRaw:  Int(player.repeatMode.rawValue),
                isAutoPlayEnabled: isAutoPlayEnabled
            )
        } catch {
            print("⚠️ State save error: \(error.localizedDescription)")
        }
    }
}
