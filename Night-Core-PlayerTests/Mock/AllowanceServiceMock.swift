import Foundation
@testable import Night_Core_Player

@MainActor
final class AllowanceServiceMock: AllowanceService {
    var entitlementResult: PlaybackEntitlement = .free(remaining: Constants.Allowance.dailyFreeSeconds)

    private(set) var consumeArgs: [(seconds: TimeInterval, now: Date)] = []

    func entitlement(now: Date) throws -> PlaybackEntitlement {
        entitlementResult
    }

    func consume(_ seconds: TimeInterval, now: Date) throws {
        consumeArgs.append((seconds, now))
    }

    func grantReward(now: Date) throws -> TimeInterval { 0 }

    func shouldShowProPrompt(now: Date) throws -> Bool { false }

    func markProPromptShown(now: Date) throws {}
}
