import Foundation
@testable import Night_Core_Player

@MainActor
final class AllowanceServiceMock: AllowanceService {
    var entitlementResult: PlaybackEntitlement = .free(remaining: Constants.Allowance.dailyFreeSeconds)
    var grantRewardError: Error?
    var shouldShowProPromptResult = false
    var markProPromptShownError: Error?

    private(set) var consumeArgs: [(seconds: TimeInterval, now: Date)] = []
    private(set) var grantRewardCallCount = 0
    private(set) var markProPromptShownCallCount = 0

    /// markProPromptShownが（エラーなく）呼ばれた後はshouldShowProPromptがfalseになる。生涯1回の実挙動を模す
    private var proPromptShown = false

    func entitlement(now: Date) throws -> PlaybackEntitlement {
        entitlementResult
    }

    func consume(_ seconds: TimeInterval, now: Date) throws {
        consumeArgs.append((seconds, now))
    }

    func grantReward(now: Date) throws -> TimeInterval {
        grantRewardCallCount += 1
        if let grantRewardError {
            throw grantRewardError
        }
        return 0
    }

    var rewardsRemainingTodayResult = Constants.Allowance.dailyRewardLimit

    func rewardsRemainingToday(now: Date) throws -> Int {
        rewardsRemainingTodayResult
    }

    func shouldShowProPrompt(now: Date) throws -> Bool {
        shouldShowProPromptResult && !proPromptShown
    }

    func markProPromptShown(now: Date) throws {
        markProPromptShownCallCount += 1
        if let markProPromptShownError {
            throw markProPromptShownError
        }
        proPromptShown = true
    }

    func debugExhaust(now: Date) throws {
        entitlementResult = .exhausted
    }

    func debugReset() throws {
        entitlementResult = .free(remaining: Constants.Allowance.dailyFreeSeconds)
        proPromptShown = false
    }
}
