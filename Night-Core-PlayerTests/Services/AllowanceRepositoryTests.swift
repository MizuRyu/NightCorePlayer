import Testing
import Foundation
import NightCoreDomain

@testable import Night_Core_Player

/// 残高ロジックのテストは NightCoreDomain 側 (fake ベース) にある。
/// ここは SwiftData 実装そのものの検証を担当する
@Suite("AllowanceRepository Tests", .serialized)
@MainActor
struct AllowanceRepositoryTests {

    // MARK: - Helpers

    private static let day0 = ISO8601DateFormatter().date(from: "2026-08-01T12:00:00+09:00")!

    private static func makeRepo() throws -> AllowanceRepository {
        let repo = AllowanceRepository(context: TestDataStore.container.mainContext)
        try repo.reset()
        return repo
    }

    // MARK: - loadOrCreate

    @Test("loadOrCreate: 初回はエンティティを作り、既定の残高で返すこと")
    func loadOrCreate_firstCall_createsWithDefaults() throws {
        let repo = try Self.makeRepo()

        let snapshot = try repo.loadOrCreate(now: Self.day0)

        #expect(snapshot.firstLaunchAt == Self.day0)
        #expect(snapshot.lastSeenAt == Self.day0)
        #expect(snapshot.nextResetAt == Self.day0.addingTimeInterval(86400))
        #expect(snapshot.remainingSeconds == Constants.Allowance.dailyFreeSeconds)
        #expect(snapshot.rewardCountTotal == 0)
        #expect(snapshot.rewardCountToday == 0)
        #expect(snapshot.proPromptShown == false)
    }

    @Test("loadOrCreate: 2回目以降は now が進んでも初回のスナップショットを返すこと")
    func loadOrCreate_secondCall_returnsExistingSnapshot() throws {
        let repo = try Self.makeRepo()
        let created = try repo.loadOrCreate(now: Self.day0)

        // 作成済みなら now は無視される。日次リセットの判定は AllowanceService の責務
        let reloaded = try repo.loadOrCreate(now: Self.day0.addingTimeInterval(86400 * 3))

        #expect(reloaded == created)
    }

    // MARK: - save

    @Test("save: 全フィールドが Repository を作り直しても復元されること")
    func save_allFields_surviveRepositoryRecreation() throws {
        let repo = try Self.makeRepo()
        _ = try repo.loadOrCreate(now: Self.day0)

        let saved = AllowanceSnapshot(
            firstLaunchAt: Self.day0.addingTimeInterval(-3600),
            nextResetAt: Self.day0.addingTimeInterval(7200),
            remainingSeconds: 1234,
            lastSeenAt: Self.day0.addingTimeInterval(600),
            rewardCountTotal: 7,
            rewardCountToday: 3,
            proPromptShown: true
        )
        try repo.save(saved)

        // 別インスタンスから読み直しても永続化された値が返る
        let recreated = AllowanceRepository(context: TestDataStore.container.mainContext)
        #expect(try recreated.loadOrCreate(now: Self.day0) == saved)
    }

    @Test("save: エンティティ未作成でも保存できること")
    func save_withoutExistingEntity_insertsSnapshot() throws {
        let repo = try Self.makeRepo()

        let saved = AllowanceSnapshot(
            firstLaunchAt: Self.day0,
            nextResetAt: Self.day0.addingTimeInterval(86400),
            remainingSeconds: 600,
            lastSeenAt: Self.day0,
            rewardCountTotal: 1,
            rewardCountToday: 1,
            proPromptShown: false
        )
        try repo.save(saved)

        #expect(try repo.loadOrCreate(now: Self.day0) == saved)
    }

    // MARK: - reset

    @Test("reset: 記録が消え、次の loadOrCreate が初回扱いになること")
    func reset_afterSave_returnsToInitialState() throws {
        let repo = try Self.makeRepo()
        var snapshot = try repo.loadOrCreate(now: Self.day0)
        snapshot.remainingSeconds = 0
        snapshot.rewardCountTotal = 5
        try repo.save(snapshot)

        try repo.reset()

        let recreatedDay = Self.day0.addingTimeInterval(86400)
        let fresh = try repo.loadOrCreate(now: recreatedDay)
        #expect(fresh.firstLaunchAt == recreatedDay)
        #expect(fresh.remainingSeconds == Constants.Allowance.dailyFreeSeconds)
        #expect(fresh.rewardCountTotal == 0)
    }
}
