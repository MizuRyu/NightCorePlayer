import Foundation
import Testing
import NightCoreDomain

/// AllowanceRepositoryPort の契約検証。fake(InMemoryAllowanceRepository)と
/// アプリ側の永続化実装(AllowanceRepository)の両方から同じアサーションを実行するために使う。
/// 永続化の検証(作り直して復元)が必要なため、インスタンスでなくファクトリを受け取る
public enum AllowanceRepositoryContract {

    public static func verifyLoadOrCreate(
        _ make: () throws -> any AllowanceRepositoryPort,
        now: Date
    ) throws {
        let repo = try make()

        let created = try repo.loadOrCreate(now: now)
        #expect(created.firstLaunchAt == now)
        #expect(created.lastSeenAt == now)
        #expect(created.nextResetAt == now.addingTimeInterval(86400))
        #expect(created.remainingSeconds == Constants.Allowance.dailyFreeSeconds)
        #expect(created.rewardCountTotal == 0)
        #expect(created.rewardCountToday == 0)
        #expect(created.proPromptShown == false)

        // 作成済みなら now は無視される。日次リセットの判定は AllowanceService の責務
        let reloaded = try repo.loadOrCreate(now: now.addingTimeInterval(86400 * 3))
        #expect(reloaded == created)
    }

    public static func verifySave(
        _ make: () throws -> any AllowanceRepositoryPort,
        now: Date
    ) throws {
        let repo = try make()

        // エンティティ未作成でも保存できること
        let inserted = AllowanceSnapshot(
            firstLaunchAt: now,
            nextResetAt: now.addingTimeInterval(86400),
            remainingSeconds: 600,
            lastSeenAt: now,
            rewardCountTotal: 1,
            rewardCountToday: 1,
            proPromptShown: false
        )
        try repo.save(inserted)
        #expect(try repo.loadOrCreate(now: now) == inserted)

        // 全フィールドが Repository を作り直しても復元されること
        let updated = AllowanceSnapshot(
            firstLaunchAt: now.addingTimeInterval(-3600),
            nextResetAt: now.addingTimeInterval(7200),
            remainingSeconds: 1234,
            lastSeenAt: now.addingTimeInterval(600),
            rewardCountTotal: 7,
            rewardCountToday: 3,
            proPromptShown: true
        )
        try repo.save(updated)

        let recreated = try make()
        #expect(try recreated.loadOrCreate(now: now) == updated)
    }

    public static func verifyReset(
        _ make: () throws -> any AllowanceRepositoryPort,
        now: Date
    ) throws {
        let repo = try make()
        var snapshot = try repo.loadOrCreate(now: now)
        snapshot.remainingSeconds = 0
        snapshot.rewardCountTotal = 5
        try repo.save(snapshot)

        try repo.reset()

        let recreatedDay = now.addingTimeInterval(86400)
        let fresh = try repo.loadOrCreate(now: recreatedDay)
        #expect(fresh.firstLaunchAt == recreatedDay)
        #expect(fresh.remainingSeconds == Constants.Allowance.dailyFreeSeconds)
        #expect(fresh.rewardCountTotal == 0)
    }
}
