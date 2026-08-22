import Foundation

enum PlaybackEntitlement: Equatable, Sendable {
    case trial(endsAt: Date)
    case free(remaining: TimeInterval)
    case exhausted
}

struct AllowanceSnapshot: Equatable, Sendable {
    var firstLaunchAt: Date
    var lastResetDayKey: String
    var remainingSeconds: TimeInterval
    var lastSeenAt: Date
    var rewardCountTotal: Int
    var proPromptShown: Bool
}
