import Foundation

enum PlaybackEntitlement: Equatable, Sendable {
    case trial(endsAt: Date)
    case free(remaining: TimeInterval)
    case exhausted
}

struct AllowanceSnapshot: Equatable, Sendable {
    var firstLaunchAt: Date
    var nextResetAt: Date
    var remainingSeconds: TimeInterval
    var lastSeenAt: Date
    var rewardCountTotal: Int
    var proPromptShown: Bool
}
