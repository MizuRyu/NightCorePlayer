import Foundation
import NightCoreDomain

/// アプリ側の永続化実装(HistoryRepository)の挙動を配列1本で模す。
/// 新しい順を保ち、上限を超えたら古い方から切り詰める点も実装に合わせる。
/// 「別インスタンスから読み直しても復元される」テスト前提は、
/// 同じ store を共有する別インスタンスを渡すことで保つ
public final class InMemoryHistoryRepository: HistoryRepositoryPort {
    private let store: InMemoryHistoryStore

    public init(store: InMemoryHistoryStore = InMemoryHistoryStore()) {
        self.store = store
    }

    public func append(songID: String) throws {
        store.songIDs.insert(songID, at: 0)
        let overflow = store.songIDs.count - Constants.History.maxHistoryCount
        if overflow > 0 {
            store.songIDs.removeLast(overflow)
        }
    }

    public func loadAll() throws -> [String] {
        store.songIDs
    }

    public func clear() throws {
        store.songIDs.removeAll()
    }
}
