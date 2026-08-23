import Foundation
import SwiftData

@Model
final class AllowanceEntity {
    @Attribute(.unique) var id: String = "default"

    var firstLaunchAt: Date
    var nextResetAt: Date
    var remainingSeconds: Double
    var lastSeenAt: Date
    var rewardCountTotal: Int
    var proPromptShown: Bool

    init(
        firstLaunchAt: Date,
        nextResetAt: Date,
        remainingSeconds: Double = Constants.Allowance.dailyFreeSeconds,
        lastSeenAt: Date,
        rewardCountTotal: Int = 0,
        proPromptShown: Bool = false
    ) {
        self.firstLaunchAt = firstLaunchAt
        self.nextResetAt = nextResetAt
        self.remainingSeconds = remainingSeconds
        self.lastSeenAt = lastSeenAt
        self.rewardCountTotal = rewardCountTotal
        self.proPromptShown = proPromptShown
    }
}
