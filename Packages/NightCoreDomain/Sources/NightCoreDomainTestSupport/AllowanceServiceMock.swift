import Foundation
import NightCoreDomain

@MainActor
public final class AllowanceServiceMock: AllowanceService {
    public var entitlementResult: PlaybackEntitlement = .free(remaining: Constants.Allowance.dailyFreeSeconds)
    public var grantRewardError: Error?
    public var shouldShowProPromptResult = false
    public var markProPromptShownError: Error?

    public private(set) var consumeArgs: [(seconds: TimeInterval, now: Date)] = []
    public private(set) var grantRewardCallCount = 0
    public private(set) var markProPromptShownCallCount = 0

    /// markProPromptShownが（エラーなく）呼ばれた後はshouldShowProPromptがfalseになる。生涯1回の実挙動を模す
    private var proPromptShown = false

    public init() {}

    public func entitlement(now: Date) throws -> PlaybackEntitlement {
        entitlementResult
    }

    public func consume(_ seconds: TimeInterval, now: Date) throws {
        consumeArgs.append((seconds, now))
    }

    public func grantReward(now: Date) throws -> TimeInterval {
        grantRewardCallCount += 1
        if let grantRewardError {
            throw grantRewardError
        }
        return 0
    }

    public var rewardsRemainingTodayResult = Constants.Allowance.dailyRewardLimit

    public func rewardsRemainingToday(now: Date) throws -> Int {
        rewardsRemainingTodayResult
    }

    public func shouldShowProPrompt(now: Date) throws -> Bool {
        shouldShowProPromptResult && !proPromptShown
    }

    public func markProPromptShown(now: Date) throws {
        markProPromptShownCallCount += 1
        if let markProPromptShownError {
            throw markProPromptShownError
        }
        proPromptShown = true
    }

    public func debugExhaust(now: Date) throws {
        entitlementResult = .exhausted
    }

    public func debugReset() throws {
        entitlementResult = .free(remaining: Constants.Allowance.dailyFreeSeconds)
        proPromptShown = false
    }
}
