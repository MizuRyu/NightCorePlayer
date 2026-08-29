import Testing
import Foundation
import SwiftData

@testable import Night_Core_Player

@Suite("AllowanceService Tests", .serialized)
@MainActor
struct AllowanceServiceTests {

    // MARK: - Helpers

    private static let day0 = ISO8601DateFormatter().date(from: "2026-08-01T12:00:00+09:00")!
    private static let daySeconds: TimeInterval = 86400

    private static func makeService() throws -> (service: AllowanceServiceImpl, repo: AllowanceRepository) {
        let context = TestDataStore.container.mainContext
        let repo = AllowanceRepository(context: context)
        try repo.reset()
        let service = AllowanceServiceImpl(repo: repo)
        return (service, repo)
    }

    private static func afterTrial(_ days: Int = 8, hours: Double = 0) -> Date {
        day0.addingTimeInterval(TimeInterval(days) * 86400 + hours * 3600)
    }

    // MARK: - Trial

    @Test
    func firstLaunch_startsTrial() throws {
        let (service, _) = try Self.makeService()
        let state = try service.entitlement(now: Self.day0)
        guard case .trial(let endsAt) = state else {
            Issue.record("trial ではない: \(state)")
            return
        }
        #expect(endsAt > Self.day0)
    }

    @Test
    func duringTrial_consumeIsNoOp() throws {
        let (service, _) = try Self.makeService()
        _ = try service.entitlement(now: Self.day0)
        try service.consume(1800, now: Self.day0.addingTimeInterval(3600))
        let state = try service.entitlement(now: Self.afterTrial())
        #expect(state == .free(remaining: Constants.Allowance.dailyFreeSeconds))
    }

    @Test
    func afterTrial_becomesFreeWithDailyAllowance() throws {
        let (service, _) = try Self.makeService()
        _ = try service.entitlement(now: Self.day0)
        let state = try service.entitlement(now: Self.afterTrial())
        #expect(state == .free(remaining: Constants.Allowance.dailyFreeSeconds))
    }

    @Test
    func trialEnd_exactBoundary_isNotTrial() throws {
        let (service, _) = try Self.makeService()
        _ = try service.entitlement(now: Self.day0)
        let end = Self.day0.addingTimeInterval(TimeInterval(Constants.Allowance.trialDays) * Self.daySeconds)

        guard case .trial = try service.entitlement(now: end.addingTimeInterval(-1)) else {
            Issue.record("期限1秒前はトライアルであるべき")
            return
        }

        let stateAtEnd = try service.entitlement(now: end)
        if case .trial(let endsAt) = stateAtEnd {
            Issue.record("境界ちょうどはトライアルではないべき: endsAt=\(endsAt)")
        }
    }

    @Test
    func futureFirstLaunch_trialInvalid() throws {
        let (service, _) = try Self.makeService()
        // 初回起動を実時刻より1年未来に偽装して作成
        let futureLaunch = Self.day0.addingTimeInterval(365 * Self.daySeconds)
        _ = try service.entitlement(now: futureLaunch)

        // 実時刻が初回起動より過去なのでトライアルではなく free 側に落ちる
        let state = try service.entitlement(now: Self.day0)
        #expect(state == .free(remaining: Constants.Allowance.dailyFreeSeconds))
    }

    // MARK: - Consume / Exhaust

    @Test
    func consume_reducesRemaining() throws {
        let (service, _) = try Self.makeService()
        _ = try service.entitlement(now: Self.day0)
        let now = Self.afterTrial()
        try service.consume(600, now: now)
        let state = try service.entitlement(now: now)
        #expect(state == .free(remaining: Constants.Allowance.dailyFreeSeconds - 600))
    }

    @Test
    func consume_toZero_becomesExhausted() throws {
        let (service, _) = try Self.makeService()
        _ = try service.entitlement(now: Self.day0)
        let now = Self.afterTrial()
        try service.consume(Constants.Allowance.dailyFreeSeconds + 100, now: now)
        let state = try service.entitlement(now: now)
        #expect(state == .exhausted)
    }

    @Test
    func consume_negativeSeconds_doesNotIncrease() throws {
        let (service, _) = try Self.makeService()
        _ = try service.entitlement(now: Self.day0)
        let now = Self.afterTrial()
        try service.consume(-500, now: now)
        let state = try service.entitlement(now: now)
        #expect(state == .free(remaining: Constants.Allowance.dailyFreeSeconds))
    }

    // MARK: - Daily reset

    @Test
    func newDay_resetsToDailyAllowance() throws {
        let (service, _) = try Self.makeService()
        _ = try service.entitlement(now: Self.day0)
        let day8 = Self.afterTrial()
        try service.consume(Constants.Allowance.dailyFreeSeconds, now: day8)
        #expect(try service.entitlement(now: day8) == .exhausted)

        let day9 = Self.afterTrial(9)
        let state = try service.entitlement(now: day9)
        #expect(state == .free(remaining: Constants.Allowance.dailyFreeSeconds))
    }

    @Test
    func reset_boundaryExact_resetsOnlyAtNextResetAt() throws {
        let (service, _) = try Self.makeService()
        _ = try service.entitlement(now: Self.day0)
        let start = Self.afterTrial()
        try service.consume(Constants.Allowance.dailyFreeSeconds, now: start)
        #expect(try service.entitlement(now: start) == .exhausted)

        // リセット境界の1秒前ではリセットされない
        let justBeforeReset = start.addingTimeInterval(Self.daySeconds - 1)
        #expect(try service.entitlement(now: justBeforeReset) == .exhausted)

        // guarded == nextResetAt のちょうど時点でリセットされる
        let boundary = start.addingTimeInterval(Self.daySeconds)
        let state = try service.entitlement(now: boundary)
        #expect(state == .free(remaining: Constants.Allowance.dailyFreeSeconds))
    }

    @Test
    func newDay_rewardBalanceDoesNotCarryOver() throws {
        let (service, _) = try Self.makeService()
        _ = try service.entitlement(now: Self.day0)
        let day8 = Self.afterTrial()
        _ = try service.grantReward(now: day8)
        let day9 = Self.afterTrial(9)
        let state = try service.entitlement(now: day9)
        #expect(state == .free(remaining: Constants.Allowance.dailyFreeSeconds))
    }

    @Test
    func backwardClock_doesNotRefill() throws {
        let (service, _) = try Self.makeService()
        _ = try service.entitlement(now: Self.day0)
        let day8 = Self.afterTrial()
        try service.consume(Constants.Allowance.dailyFreeSeconds, now: day8)
        #expect(try service.entitlement(now: day8) == .exhausted)

        // 時計を前日に戻しても lastSeenAt でガードされ、リセットされない
        let day7 = Self.afterTrial(7)
        let state = try service.entitlement(now: day7)
        #expect(state == .exhausted)
    }

    // MARK: - Reward

    @Test
    func grantReward_addsRewardSeconds() throws {
        let (service, _) = try Self.makeService()
        _ = try service.entitlement(now: Self.day0)
        let now = Self.afterTrial()
        try service.consume(Constants.Allowance.dailyFreeSeconds, now: now)
        let remaining = try service.grantReward(now: now)
        #expect(remaining == Constants.Allowance.rewardSeconds)
        #expect(try service.entitlement(now: now) == .free(remaining: Constants.Allowance.rewardSeconds))
    }

    // MARK: - Persistence

    @Test
    func persistence_survivesServiceRecreation() throws {
        let (service, _) = try Self.makeService()
        _ = try service.entitlement(now: Self.day0)
        let now = Self.afterTrial()

        try service.consume(600, now: now)
        for _ in 0..<Constants.Allowance.proPromptRewardCount {
            _ = try service.grantReward(now: now)
        }
        try service.markProPromptShown(now: now)

        // Service/Repository を作り直しても状態が維持される
        let recreatedRepo = AllowanceRepository(context: TestDataStore.container.mainContext)
        let recreated = AllowanceServiceImpl(repo: recreatedRepo)

        let expectedRemaining =
            Constants.Allowance.dailyFreeSeconds - 600
            + Constants.Allowance.rewardSeconds * TimeInterval(Constants.Allowance.proPromptRewardCount)
        #expect(try recreated.entitlement(now: now) == .free(remaining: expectedRemaining))

        // rewardCountTotal >= 閾値かつ proPromptShown 済なので false であるべき
        #expect(try recreated.shouldShowProPrompt(now: now) == false)
    }

    // MARK: - Pro prompt

    @Test
    func proPrompt_shownOnceAfterThresholdRewards() throws {
        let (service, _) = try Self.makeService()
        _ = try service.entitlement(now: Self.day0)
        let now = Self.afterTrial()

        for i in 0..<Constants.Allowance.proPromptRewardCount {
            #expect(try service.shouldShowProPrompt(now: now) == false, "\(i)回目で早期表示")
            _ = try service.grantReward(now: now)
        }
        #expect(try service.shouldShowProPrompt(now: now) == true)

        try service.markProPromptShown(now: now)
        #expect(try service.shouldShowProPrompt(now: now) == false)
    }
}
