import Foundation
import MusicKit

// MARK: - Protocol

@MainActor
protocol PlayHistoryManaging: Sendable {
    var history: [Song] { get }
    func append(_ song: Song) throws
    func clearHistory() throws
    func restoreHistory(_ songs: [Song])
}

// MARK: - Impl

@MainActor
final class PlayHistoryManagerImpl: PlayHistoryManaging {
    private let historyRepo: HistoryRepository
    private let maxHistoryCount: Int = Constants.History.maxHistoryCount

    private(set) var history: [Song] = []

    init(historyRepo: HistoryRepository) {
        self.historyRepo = historyRepo
    }

    func append(_ song: Song) throws {
        guard history.last?.id.rawValue != song.id.rawValue else { return }
        history.append(song)
        if history.count > maxHistoryCount {
            history.removeFirst(history.count - maxHistoryCount)
        }
        try historyRepo.append(songID: song.id.rawValue)
    }

    func clearHistory() throws {
        history.removeAll()
        try historyRepo.clear()
    }

    func restoreHistory(_ songs: [Song]) {
        history = songs
    }
}
