import Testing
import Combine
import SwiftUI
import MusicKit
import MediaPlayer
@testable import Night_Core_Player

final class PlayerControllableMock: PlayerControllable {
    var playbackState: MPMusicPlaybackState = .paused
    var currentTime: TimeInterval = 0
    var nowPlayingItem: MPMediaItem? = nil
    var indexOfNowPlayingItem: Int = 0
    var playbackRate: Double = 1.0
    
    var shuffleMode: MPMusicShuffleMode = .off
    var repeatMode: MPMusicRepeatMode = .none

    // 呼び出し回数／引数を記録
    private(set) var playCount = 0
    private(set) var pauseCount = 0
    private(set) var seekArgs: [TimeInterval] = []
    private(set) var skipNextCount = 0
    private(set) var skipPreviousCount = 0
    private(set) var setQueueDescriptors: [MPMusicPlayerPlayParametersQueueDescriptor] = []
    private(set) var prependDescriptors: [MPMusicPlayerPlayParametersQueueDescriptor] = []
    private(set) var stopCount = 0

    func play() {
        playCount += 1
        playbackState = .playing
    }

    func pause() {
        pauseCount += 1
        playbackState = .paused
    }

    func seek(to time: TimeInterval) {
        seekArgs.append(time)
        currentTime = time
    }

    func skipToNext() {
        skipNextCount += 1
        indexOfNowPlayingItem += 1
    }

    func skipToPrevious() {
        skipPreviousCount += 1
        indexOfNowPlayingItem = max(0, indexOfNowPlayingItem - 1)
    }

    func setQueue(with descriptor: MPMusicPlayerPlayParametersQueueDescriptor) {
        setQueueDescriptors.append(descriptor)
    }

    func prepend(_ descriptor: MPMusicPlayerPlayParametersQueueDescriptor) {
        prependDescriptors.append(descriptor)
    }

    func stop() {
        stopCount += 1
        playbackState = .stopped
    }
}

final class QueueManagingMock: QueueManaging {
    // キュー状態を外部から設定可能
    var items: [Song] = []
    var currentIndex: Int = 0

    var currentSong: Song? {
        guard items.indices.contains(currentIndex) else { return nil }
        return items[currentIndex]
    }
    var isEmpty: Bool { items.isEmpty }

    // 呼び出しトラッキング
    private(set) var setQueueArgs: [([Song], Int)] = []
    private(set) var moveArgs: [(from: Int, to: Int)] = []
    private(set) var removeArgs: [Int] = []
    private(set) var insertNextArgs: [Song] = []

    func setQueue(_ songs: [Song], startAt idx: Int) async -> QueueUpdateAction {
        setQueueArgs.append((songs, idx))
        items = songs
        currentIndex = min(max(idx, 0), songs.count - 1)
        return .playNewQueue
    }

    func moveItem(from src: Int, to dst: Int) async -> QueueUpdateAction {
        moveArgs.append((src, dst))
        guard items.indices.contains(src), items.indices.contains(dst), src != dst else {
            return .noAction
        }
        let song = items.remove(at: src)
        items.insert(song, at: dst)
        // currentIndex の調整
        if src == currentIndex {
            currentIndex = dst
        } else if src < currentIndex && dst >= currentIndex {
            currentIndex -= 1
        } else if src > currentIndex && dst <= currentIndex {
            currentIndex += 1
        }
        return .updatePlayerQueueOnly
    }

    func removeItem(at idx: Int) async -> (action: QueueUpdateAction, removed: Song?) {
        removeArgs.append(idx)
        guard items.indices.contains(idx) else {
            return (.noAction, nil)
        }
        let removed = items.remove(at: idx)
        if items.isEmpty {
            currentIndex = 0
            return (.playerShouldStop, removed)
        }
        if idx < currentIndex {
            currentIndex -= 1
            return (.updatePlayerQueueOnly, removed)
        } else if idx == currentIndex {
            currentIndex = min(currentIndex, items.count - 1)
            return (.playNewQueue, removed)
        }
        return (.updatePlayerQueueOnly, removed)
    }

    func insertNext(_ song: Song) async -> (action: QueueUpdateAction, newIndex: Int?) {
        insertNextArgs.append(song)
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
        // Player用に currentIndex から回転
        guard !items.isEmpty else { return [] }
        return Array(items[currentIndex...] + items[..<currentIndex])
    }
}

final class MusicPlayerServiceMock: MusicPlayerService {
    private(set) var setQueueArgs: [([Song], Int)] = []
    private(set) var playCounted     = 0
    private(set) var pauseCounted    = 0
    private(set) var nextCounted     = 0
    private(set) var previousCounted = 0
    private(set) var clearHistoryCounted = 0
    private(set) var seekArgs: [TimeInterval] = []
    private(set) var rateArgs: [Double]        = []
    private(set) var moveArgs: [(Int, Int)]    = []
    private(set) var removeArgs: [Int]         = []
    private(set) var playNowArgs: [Song]       = []
    private(set) var insertNextArgs: [Song]    = []
    // テストから send できる Subject
    public let snapshotSubject = PassthroughSubject<MusicPlayerSnapshot, Never>()
    public var snapshotPublisher: AnyPublisher<MusicPlayerSnapshot, Never> {
        snapshotSubject.eraseToAnyPublisher()
    }

    // ViewModel が参照する状態
    public var musicPlayerQueue: [Song] = []
    public var nowPlayingIndex: Int     = 0
    public var playHistory: [Song]      = []
    
    // ★ ここを追加
    public private(set) var isShuffled: Bool       = false
    public private(set) var repeatMode: Constants.RepeatMode = .none
    

    public func setQueue(songs: [Song], startAt index: Int) async {
        setQueueArgs.append((songs, index))
        musicPlayerQueue = songs
        nowPlayingIndex  = index
        snapshotSubject.send(.empty)
    }

    public func play() async {
        playCounted += 1
        snapshotSubject.send(.empty.withPlaying(true))
    }

    public func pause() async {
        pauseCounted += 1
        snapshotSubject.send(.empty.withPlaying(false))
    }

    public func next() async {
        nextCounted += 1
    }

    public func previous() async {
        previousCounted += 1
    }

    public func seek(to time: TimeInterval) async {
        seekArgs.append(time)
        snapshotSubject.send(.empty.withCurrentTime(time))
    }

    public func changeRate(to newRate: Double) async {
        rateArgs.append(newRate)
        snapshotSubject.send(.empty.withRate(newRate))
    }

    public func moveItem(from src: Int, to dst: Int) async {
        moveArgs.append((src, dst))
    }

    public func removeItem(at idx: Int) async {
        removeArgs.append(idx)
    }

    public func insertNext(_ song: Song) async {
        insertNextArgs.append(song)
        let insertAt = nowPlayingIndex + 1
        if musicPlayerQueue.isEmpty {
            musicPlayerQueue = [song]
            nowPlayingIndex = 0
        } else if insertAt >= 0 && insertAt <= musicPlayerQueue.count {
            musicPlayerQueue.insert(song, at: insertAt)
        }
        // ViewModel に反映されるように snapshot を送る
        snapshotSubject.send(.empty)
    }
    public func playNow(_ song: Song) async {
        playNowArgs.append(song)
        musicPlayerQueue = [song]
        nowPlayingIndex = 0
        snapshotSubject.send(.empty.withPlaying(true))
    }

    public func clearHistory() {
        clearHistoryCounted += 1
        playHistory.removeAll()
    }
    
    public func toggleShuffle() async {
        isShuffled.toggle()
    }
    
    public func cycleRepeatMode() async {
        switch repeatMode {
        case .none: repeatMode = .all
        case .all:  repeatMode = .one
        case .one:  repeatMode = .none
        }
    }
}

extension MusicPlayerSnapshot {
    // テスト時に一部フィールドだけ変えたいときのヘルパー
    func withPlaying(_ playing: Bool) -> MusicPlayerSnapshot {
        .init(title: title,
              artist: artist,
              artwork: artwork,
              currentTime: currentTime,
              duration: duration,
              rate: rate,
              isPlaying: playing)
    }
    func withCurrentTime(_ t: TimeInterval) -> MusicPlayerSnapshot {
        .init(title: title,
              artist: artist,
              artwork: artwork,
              currentTime: t,
              duration: duration,
              rate: rate,
              isPlaying: isPlaying)
    }
    func withRate(_ r: Double) -> MusicPlayerSnapshot {
        .init(title: title,
              artist: artist,
              artwork: artwork,
              currentTime: currentTime,
              duration: duration,
              rate: r,
              isPlaying: isPlaying)
    }
}

