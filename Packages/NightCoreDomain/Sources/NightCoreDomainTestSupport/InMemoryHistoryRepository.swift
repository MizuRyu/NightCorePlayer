import Foundation
import NightCoreDomain

/// アプリ側の永続化実装(HistoryRepository)の挙動を配列1本で模す。
/// 新しい順を保ち、上限を超えたら古い方から切り詰める点も実装に合わせる
public final class InMemoryHistoryRepository: HistoryRepositoryPort {
    private var songIDs: [String] = []

    public init() {}

    public func append(songID: String) throws {
        songIDs.insert(songID, at: 0)
        let overflow = songIDs.count - Constants.History.maxHistoryCount
        if overflow > 0 {
            songIDs.removeLast(overflow)
        }
    }

    public func loadAll() throws -> [String] {
        songIDs
    }

    public func clear() throws {
        songIDs.removeAll()
    }
}
