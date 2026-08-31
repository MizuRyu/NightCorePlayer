import Foundation
import NightCoreDomain

/// InMemoryAllowanceRepository のバックストア。外部から注入できるようにすることで、
/// 「同じ store を共有する別インスタンスの fake」を作れる。
/// これにより contract の「Repository を作り直しても復元される」検証を fake 側でも本物にする
public final class InMemoryAllowanceStore {
    public var snapshot: AllowanceSnapshot?

    public init(snapshot: AllowanceSnapshot? = nil) {
        self.snapshot = snapshot
    }
}
