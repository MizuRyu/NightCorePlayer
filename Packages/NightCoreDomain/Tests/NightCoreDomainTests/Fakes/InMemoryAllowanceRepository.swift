import Foundation
import NightCoreDomain
import NightCoreDomainTestSupport

/// SwiftData 実装 (AllowanceRepository) の永続化挙動を変数1本で模す。
/// 「Service/Repository を作り直しても状態が維持される」テスト前提は、
/// 同じ store を共有する別インスタンスを渡すことで保つ
final class InMemoryAllowanceRepository: AllowanceRepositoryPort {
    private let store: InMemoryAllowanceStore

    init(store: InMemoryAllowanceStore = InMemoryAllowanceStore()) {
        self.store = store
    }

    func loadOrCreate(now: Date) throws -> AllowanceSnapshot {
        if let snapshot = store.snapshot {
            return snapshot
        }
        // 初回作成時の既定値は AllowanceEntity の init に合わせる
        let snapshot = AllowanceSnapshot(
            firstLaunchAt: now,
            nextResetAt: now.addingTimeInterval(86400),
            remainingSeconds: Constants.Allowance.dailyFreeSeconds,
            lastSeenAt: now,
            rewardCountTotal: 0,
            rewardCountToday: 0,
            proPromptShown: false
        )
        store.snapshot = snapshot
        return snapshot
    }

    func save(_ snapshot: AllowanceSnapshot) throws {
        store.snapshot = snapshot
    }

    func reset() throws {
        store.snapshot = nil
    }
}
