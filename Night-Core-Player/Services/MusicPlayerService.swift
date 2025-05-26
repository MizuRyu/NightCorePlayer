import Combine
import MediaPlayer
import MusicKit
import SwiftUI

@MainActor
public protocol PlayerControllable: Sendable {
    var playbackState: MPMusicPlaybackState { get }
    var currentTime: TimeInterval { get }
    var nowPlayingItem: MPMediaItem? { get }
    var indexOfNowPlayingItem: Int { get }
    var playbackRate: Double { get set }
    
    var shuffleMode: MPMusicShuffleMode { get set }
    var repeatMode: MPMusicRepeatMode { get set }

    func play()
    func pause()
    func seek(to time: TimeInterval)
    func skipToNext()
    func skipToPrevious()
    func setQueue(with descriptor: MPMusicPlayerPlayParametersQueueDescriptor)
    func prepend(_ descriptor: MPMusicPlayerPlayParametersQueueDescriptor)
    func stop()
}

public enum QueueUpdateAction: Sendable {
    case playNewQueue // 新しいキューで再生開始
    case updatePlayerQueueOnly // プレイヤーのキューのみ更新（View）
    case playCurrentTrack // 現在のトラックを再生
    case playerShouldStop // プレイヤーを停止
    case noAction
}

@MainActor
public protocol QueueManaging: Sendable {
    var items: [Song] { get }
    var currentIndex: Int { get set }
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

/// 再生操作、プレイヤーの状態取得
@MainActor
final class MPMusicPlayerAdapter: PlayerControllable {
    private let player = MPMusicPlayerController.applicationQueuePlayer

    init(defaultRate: Double) {
        player.beginGeneratingPlaybackNotifications()
        player.currentPlaybackRate = Float(defaultRate)
        player.shuffleMode = .off
        player.repeatMode = .none
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
    var shuffleMode: MPMusicShuffleMode {
        get { player.shuffleMode }
        set { player.shuffleMode = newValue }
    }
    var repeatMode: MPMusicRepeatMode {
        get { player.repeatMode }
        set { player.repeatMode = newValue }
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

/// 再生キューの論理操作を集約
@MainActor
public final class MusicQueueManager: QueueManaging {
    public var items: [Song] = []
    public var currentIndex: Int = 0
    
    public var isEmpty: Bool { items.isEmpty}
    public var currentSong: Song? {
        guard items.indices.contains(currentIndex) else { return nil }
        return items[currentIndex]
    }
    
    // 指定されたインデックスから開始するように、再生キューを設定
    public func setQueue(_ songs: [Song], startAt idx: Int) async -> QueueUpdateAction {
        items = songs
        if songs.isEmpty {
            currentIndex = 0
            return .playerShouldStop
        }
        currentIndex = songs.isEmpty ? 0 : min(max(idx, 0), songs.count - 1)
        return .playNewQueue
    }

    public func moveItem(from src: Int, to dst: Int) async -> QueueUpdateAction {
        guard src != dst,
              items.indices.contains(src),
              items.indices.contains(dst) else { return .noAction }
        let song = items.remove(at: src)
        items.insert(song, at: dst)
        // 現在再生中のインデックスを調整する
        if src == currentIndex { currentIndex = dst }
        else if src < currentIndex && dst >= currentIndex { currentIndex -= 1 }
        else if src > currentIndex && dst <= currentIndex { currentIndex += 1 }
        return .updatePlayerQueueOnly
    }

    public func removeItem(at idx: Int) async -> (action: QueueUpdateAction, removed: Song?) {
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

    // 現在再生されている次の位置に楽曲を割り込み
    public func insertNext(_ song: Song) async -> (action: QueueUpdateAction, newIndex: Int?) {
        if items.isEmpty {
            items = [song]
            currentIndex = 0
            return (.playNewQueue, 0)
        }
        let rawIndex = currentIndex + 1
        let insertAt = min(max(rawIndex, 0), items.count)
        items.insert(song, at: insertAt)
        return (.updatePlayerQueueOnly, insertAt)
    }

    // 次の楽曲に進むことができるかどうか
    public func advanceToNextTrack() async -> Bool {
        guard currentIndex + 1 < items.count else { return false }
        currentIndex += 1
        return true
    }

    // 前の楽曲に戻ることができるかどうか
    public func regressToPreviousTrack() async -> Bool {
        guard currentIndex > 0 else { return false }
        currentIndex -= 1
        return true
    }

    public func songsForPlayerQueueDescriptor() async -> [Song] {
        guard !items.isEmpty else { return [] }
        return Array(items[currentIndex...] + items[..<currentIndex])
    }
}

/// 音楽プレイヤーの現在の状態
public struct MusicPlayerSnapshot: Sendable, Equatable {
    public let title: String
    public let artist: String
    public let artwork: Image
    public let currentTime: TimeInterval
    public let duration: TimeInterval
    public let rate: Double
    public let isPlaying: Bool
    
    public static let empty = MusicPlayerSnapshot(
        title: "-",
        artist: "-",
        artwork: Image(systemName: "music.note"),
        currentTime: 0,
        duration: 0,
        rate: Constants.MusicPlayer.defaultPlaybackRate,
        isPlaying: false
    )
}

/// Main Protocol
@MainActor
protocol MusicPlayerService: Sendable {
    var snapshotPublisher: AnyPublisher<MusicPlayerSnapshot, Never> { get }
    
    func play() async
    func pause() async
    func next() async
    func previous() async
    func seek(to time: TimeInterval) async
    func changeRate(to newRate: Double) async
    
    func setQueue(songs: [Song], startAt index: Int) async
    func moveItem(from src: Int, to dst: Int) async
    func removeItem(at idx: Int) async
    func insertNext(_ song: Song) async
    func playNow(_ song: Song) async

    var isShuffled: Bool { get }
    var repeatMode: Constants.RepeatMode { get }
    func toggleShuffle() async
    func cycleRepeatMode() async
        
    var musicPlayerQueue: [Song] { get }
    var nowPlayingIndex: Int { get }
    var playHistory: [Song] { get }
    func clearHistory()
}

/// Main
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
    private var history: [Song] = []
    
    private let defaultPlaybackRate: Double = Constants.MusicPlayer.defaultPlaybackRate
    var currentPlaybackRate: Double = Constants.MusicPlayer.defaultPlaybackRate
    private let minPlaybackRate: Double = Constants.MusicPlayer.minPlaybackRate
    private let maxPlaybackRate: Double = Constants.MusicPlayer.maxPlaybackRate
    
    
    private var timerCancellable: AnyCancellable?
    private var lastPlayerIndex: Int? = nil
    private var needsQueueRefresh: Bool = false
        
    
    public init(
        playerAdapter : PlayerControllable? = nil,
        queueManager : QueueManaging? = nil
    ) {
        self.player   = playerAdapter ?? MPMusicPlayerAdapter(defaultRate: Constants.MusicPlayer.defaultPlaybackRate)
        self.queue    = queueManager ?? MusicQueueManager()
        
        // 0.5秒ごとにcurrentTimeを更新
        timerCancellable = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.updateSnapshot() }
        
        // 曲変更通知
        NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.trackChanged() }
    }
    
    deinit {
        timerCancellable?.cancel()
        NotificationCenter.default.removeObserver(self)
    }
    
    public func setQueue(songs: [Song], startAt idx: Int) async {
        let action = await queue.setQueue(songs, startAt: idx)
        await handleQueueAction(action)
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

    // 自動スキップ時
    public func seek(to time: TimeInterval) async {
        let dur = queue.currentSong?.duration ?? player.nowPlayingItem?.playbackDuration ?? 0
        let t   = Swift.min(Swift.max(time, 0), dur)
        player.seek(to: t)
        updateSnapshot()
    }
    public func changeRate(to newRate: Double) async {
        currentPlaybackRate = Swift.min(Swift.max(newRate, minPlaybackRate), maxPlaybackRate)
        player.playbackRate = currentPlaybackRate
        updateSnapshot()
    }

    public func moveItem(from src: Int, to dst: Int) async {
        let _ = await queue.moveItem(from: src, to: dst)
    }

    public func removeItem(at idx: Int) async {
        let (action, _) = await queue.removeItem(at: idx)
        switch action {
        case .playNewQueue, .playerShouldStop:
            // キューが空になった場合はプレイヤーを停止
            await handleQueueAction(action)
        case .updatePlayerQueueOnly:
            needsQueueRefresh = true
            updateSnapshot()
        case .noAction, .playCurrentTrack:
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
            // キューが空である場合
            await handleQueueAction(action)
            return
        }
        if let pp = try? makePlayParameters(for: song) {
            player.prepend(MPMusicPlayerPlayParametersQueueDescriptor(playParametersQueue: [pp]))
        }
    }
    
    public var playHistory: [Song] { history }
    
    public func clearHistory() {
        history.removeAll()
    }
    
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
        
        // UI 用 enum にマッピング
        switch next {
        case .none: repeatMode = .none
        case .all:  repeatMode = .all
        case .one:  repeatMode = .one
        case .default: repeatMode = .none
        @unknown default: repeatMode = .none
        }
    }

    private func handleQueueAction(_ action: QueueUpdateAction) async {
        switch action {
            case .playNewQueue:
                if let descriptor = try? buildQueueDescriptor(from: await queue.items, startAt: queue.currentIndex) {
                    player.setQueue(with: descriptor)
                    player.play()
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
            case .playCurrentTrack:
                player.play()
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
        
        let artworkToShow: Image = isNewSong
        ? Image(systemName: "music.note")
        : snapshot.artwork
        
        snapshot = MusicPlayerSnapshot(
            title:       title,
            artist:      artist,
            artwork:     artworkToShow,
            currentTime: currentTime,
            duration:    duration,
            rate:        rate,
            isPlaying:   isPlaying
        )
        
        guard isNewSong else { return }
        Task { [weak self] in
            guard let self = self else { return }
            let fetchedArt = await self.getArtwork(for: song)
            let updated = MusicPlayerSnapshot(
                title:       title,
                artist:      artist,
                artwork:     fetchedArt,
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
        let currentQueueIndex = queue.currentIndex

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
        
        // 履歴更新
        if let current = queue.currentSong {
            if history.last?.id != current.id {
                history.append(current)
                let titles = history.map{ $0.title }
            }
        }
        
        updateSnapshot()
    }

    // プレイリスト（ローカル）からPlayeParametersを抽出するため
    private func makePlayParameters(for song: Song) throws -> MPMusicPlayerPlayParameters? {
        guard let playParams = song.playParameters else {
            return nil
        }
        // 冗長だがプレイリストの楽曲からPlayParametersを生成するために必要
        let data = try JSONEncoder().encode(playParams)
        let pp   = try JSONDecoder().decode(MPMusicPlayerPlayParameters.self, from: data)
        return pp
    }
    // 指定位置の楽曲を先頭に配置する
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
    
    /// カタログから楽曲詳細を取得
    private func fetchSongDetails(_ song: Song) async -> Song {
        let raw = song.id.rawValue
        // ライブラリ（プレイリスト）楽曲はカタログAPIを叩かない
        if raw.hasPrefix("i.") {
            return song
        }
        do {
            let req  = MusicCatalogResourceRequest<Song>(matching:\.id, equalTo: song.id)
            let resp = try await req.response()
            let first = resp.items.first ?? song
            return first
        } catch {
            print("⚠️ fetchSongDetails error: \(error.localizedDescription)")
            return song
        }
    }
    
    private func fetchArtwork(from art: Artwork?) async -> Image {
        let placeholder = Image(systemName: "music.note")
        guard let art = art,
              let url = art.url(width: Int(Constants.MusicPlayer.artworkSize),
                                height: Int(Constants.MusicPlayer.artworkSize))
        else {
            return placeholder
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let ui = UIImage(data: data) {
                return Image(uiImage: ui)
            } else {
            }
        } catch {
            print("⚠️ Artwork Download Error: \(error.localizedDescription)")
        }
        return placeholder
    }
    
    /// カタログまたはローカルライブラリのartworkを取得
    private func getArtwork(for song: Song?) async -> Image {
        let placeholder = Image(systemName: "music.note")
        guard let song = song else {
            return placeholder
        }
        
        let detailed = await fetchSongDetails(song)
        let fromCatalog = await fetchArtwork(from: detailed.artwork)
        if fromCatalog != placeholder {
            return fromCatalog
        }
        
        let fromOriginal = await fetchArtwork(from: song.artwork)
        if fromOriginal != placeholder {
            return fromOriginal
        }
        
        return placeholder
    }
}
