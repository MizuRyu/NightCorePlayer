import Foundation
import NightCoreDomain

/// SwiftData 実装 (AllowanceRepository) の永続化挙動を変数1本で模す。
/// 「Service を作り直しても状態が維持される」テスト前提は、同じ fake を渡すことで保つ
final class InMemoryAllowanceRepository: AllowanceRepositoryPort {
    private var stored: AllowanceSnapshot?

    func loadOrCreate(now: Date) throws -> AllowanceSnapshot {
        if let stored {
            return stored
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
        stored = snapshot
        return snapshot
    }

    func save(_ snapshot: AllowanceSnapshot) throws {
        stored = snapshot
    }

    func reset() throws {
        stored = nil
    }
}
