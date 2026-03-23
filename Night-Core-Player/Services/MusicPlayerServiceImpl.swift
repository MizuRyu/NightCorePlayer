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

    var currentPlaybackRate: Double = Constants.MusicPlayer.defaultPlaybackRate
    private let minPlaybackRate: Double = Constants.MusicPlayer.minPlaybackRate
    private let maxPlaybackRate: Double = Constants.MusicPlayer.maxPlaybackRate

    private var timerCancellable: AnyCancellable?
    private var lastPlayerIndex: Int? = nil
    private var needsQueueRefresh: Bool = false

    init(
        rateManager: PlaybackRateManager,
        persistenceService: PlayerPersistenceService,
        historyManager: PlayHistoryManaging,
        artworkService: ArtworkCacheService,
        playerAdapter : PlayerControllable? = nil,
        queueManager : QueueManaging? = nil
    ) {
        self.rateManager = rateManager
        self.persistenceService = persistenceService
        self.historyManager = historyManager
        self.artworkService = artworkService

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
        guard advanced else { return }
        await handleQueueAction(.playNewQueue)
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
        let newShuffle: MPMusicShuffleMode = (player.shuffleMode == .off) ? .songs : .off
        player.shuffleMode = newShuffle
        isShuffled = (newShuffle != .off)
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
    }

    // MARK: - Private

    private func handleQueueAction(_ action: QueueUpdateAction, autoPlay: Bool = true) async {
        switch action {
        case .playNewQueue:
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
        let title = item?.title ?? song?.title ?? "-"
        let artist = item?.artist ?? song?.artistName ?? "-"
        let duration = item?.playbackDuration ?? song?.duration ?? 0
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
                repeatModeRaw:  Int(player.repeatMode.rawValue)
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

        guard playerIndex != lastPlayerIndex else { return }
        lastPlayerIndex = playerIndex

        if playerIndex >= 0 && playerIndex < queue.items.count {
            let actualIndex = (queue.currentIndex + playerIndex) % queue.items.count

            if actualIndex != queue.currentIndex {
                queue.currentIndex = actualIndex
            } else {
                if let now = player.nowPlayingItem {
                    let pid = now.persistentID
                    if let idx = queue.items.firstIndex(where: { song in
                        let songId = UInt64(song.id.rawValue)
                        return songId == pid
                    }) {
                        if idx != queue.currentIndex {
                            queue.currentIndex = idx
                        }
                    }
                }
            }
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
        let rotated = Array(songs[index...] + songs[..<index])
        let params = try rotated.compactMap { try makePlayParameters(for: $0) }
        guard !params.isEmpty else {
            throw NSError(domain: "MusicPlayerUtils", code: -2, userInfo: nil)
        }
        return MPMusicPlayerPlayParametersQueueDescriptor(playParametersQueue: params)
    }

    private func restore() async {
        let st: (queueIDs: [String], currentIndex: Int, playbackRate: Double, shuffleModeRaw: Int, repeatModeRaw: Int)
        do {
            st = try persistenceService.loadState()
        } catch {
            st = ([], 0, Constants.MusicPlayer.defaultPlaybackRate,
                  MPMusicShuffleMode.off.rawValue, MPMusicRepeatMode.none.rawValue)
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
    }
}
