import Foundation

// MARK: - Protocol

@MainActor
public protocol PlayHistoryManaging<Item>: Sendable {
    associatedtype Item: Sendable

    var history: [Item] { get }
    func append(_ song: Item) throws
    func clearHistory() throws
    func restoreHistory(_ songs: [Item])
}

// MARK: - Impl

@MainActor
public final class PlayHistoryManagerImpl<Item: Sendable>: PlayHistoryManaging {
    private let historyRepo: any HistoryRepositoryPort
    /// 永続化に使う曲IDの取り出し方。Item の具体型に依存しないよう注入する
    private let songID: @Sendable (Item) -> String
    private let maxHistoryCount: Int = Constants.History.maxHistoryCount

    public private(set) var history: [Item] = []

    public init(
        historyRepo: any HistoryRepositoryPort,
        songID: @escaping @Sendable (Item) -> String
    ) {
        self.historyRepo = historyRepo
        self.songID = songID
    }

    public func append(_ song: Item) throws {
        let id = songID(song)
        guard history.last.map(songID) != id else { return }
        history.append(song)
        if history.count > maxHistoryCount {
            history.removeFirst(history.count - maxHistoryCount)
        }
        try historyRepo.append(songID: id)
    }

    public func clearHistory() throws {
        history.removeAll()
        try historyRepo.clear()
    }

    public func restoreHistory(_ songs: [Item]) {
        history = songs
    }
}
