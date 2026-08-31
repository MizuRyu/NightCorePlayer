import Foundation

// MARK: - QueueUpdateAction

public enum QueueUpdateAction: Sendable {
    case playNewQueue
    case updatePlayerQueueOnly
    case playerShouldStop
    case noAction
}

// MARK: - Protocol

@MainActor
public protocol QueueManaging<Item>: Sendable {
    associatedtype Item: Sendable

    var items: [Item] { get }
    var currentIndex: Int { get set }
    var currentSong: Item? { get }
    var isEmpty: Bool { get }

    func setQueue(_ songs: [Item], startAt idx: Int) async -> QueueUpdateAction
    func moveItem(from src: Int, to dst: Int) async -> QueueUpdateAction
    func removeItem(at idx: Int) async -> (action: QueueUpdateAction, removed: Item?)
    func insertNext(_ song: Item) async -> (action: QueueUpdateAction, newIndex: Int?)
    func advanceToNextTrack() async -> Bool
    func regressToPreviousTrack() async -> Bool
    func songsForPlayerQueueDescriptor() async -> [Item]
}

// MARK: - Impl

@MainActor
public final class MusicQueueManager<Item: Sendable>: QueueManaging {
    public var items: [Item] = []
    public var currentIndex: Int = 0

    public init() {}

    public var isEmpty: Bool { items.isEmpty }
    public var currentSong: Item? {
        guard items.indices.contains(currentIndex) else { return nil }
        return items[currentIndex]
    }

    public func setQueue(_ songs: [Item], startAt idx: Int) async -> QueueUpdateAction {
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
        if src == currentIndex {
            currentIndex = dst
        } else if src < currentIndex && dst >= currentIndex {
            currentIndex -= 1
        } else if src > currentIndex && dst <= currentIndex {
            currentIndex += 1
        }
        return .updatePlayerQueueOnly
    }

    public func removeItem(at idx: Int) async -> (action: QueueUpdateAction, removed: Item?) {
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

    public func insertNext(_ song: Item) async -> (action: QueueUpdateAction, newIndex: Int?) {
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

    public func advanceToNextTrack() async -> Bool {
        guard currentIndex + 1 < items.count else { return false }
        currentIndex += 1
        return true
    }

    public func regressToPreviousTrack() async -> Bool {
        guard currentIndex > 0 else { return false }
        currentIndex -= 1
        return true
    }

    public func songsForPlayerQueueDescriptor() async -> [Item] {
        guard !items.isEmpty else { return [] }
        return Array(items[currentIndex...])
    }
}
