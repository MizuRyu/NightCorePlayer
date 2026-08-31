import Foundation

public enum PlaybackEntitlement: Equatable, Sendable {
    case trial(endsAt: Date)
    case free(remaining: TimeInterval)
    case exhausted
}

public struct AllowanceSnapshot: Equatable, Sendable {
    public var firstLaunchAt: Date
    public var nextResetAt: Date
    public var remainingSeconds: TimeInterval
    public var lastSeenAt: Date
    public var rewardCountTotal: Int
    public var rewardCountToday: Int = 0
    public var proPromptShown: Bool

    public init(
        firstLaunchAt: Date,
        nextResetAt: Date,
        remainingSeconds: TimeInterval,
        lastSeenAt: Date,
        rewardCountTotal: Int,
        rewardCountToday: Int = 0,
        proPromptShown: Bool
    ) {
        self.firstLaunchAt = firstLaunchAt
        self.nextResetAt = nextResetAt
        self.remainingSeconds = remainingSeconds
        self.lastSeenAt = lastSeenAt
        self.rewardCountTotal = rewardCountTotal
        self.rewardCountToday = rewardCountToday
        self.proPromptShown = proPromptShown
    }
}
