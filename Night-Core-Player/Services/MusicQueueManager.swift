import MusicKit

@MainActor
public final class MusicQueueManager: QueueManaging {
    public var items: [Song] = []
    public var currentIndex: Int = 0

    public var isEmpty: Bool { items.isEmpty }
    public var currentSong: Song? {
        guard items.indices.contains(currentIndex) else { return nil }
        return items[currentIndex]
    }

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

    public func songsForPlayerQueueDescriptor() async -> [Song] {
        guard !items.isEmpty else { return [] }
        return Array(items[currentIndex...] + items[..<currentIndex])
    }
}
