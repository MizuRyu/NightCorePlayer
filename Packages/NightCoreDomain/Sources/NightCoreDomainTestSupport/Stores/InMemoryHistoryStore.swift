import Foundation

/// InMemoryHistoryRepository のバックストア。外部から注入できるようにすることで、
/// 「同じ store を共有する別インスタンスの fake」を作れる。
/// これにより contract の「別インスタンスから読み直しても復元される」検証を fake 側でも本物にする
public final class InMemoryHistoryStore {
    public var songIDs: [String] = []

    public init() {}
}
