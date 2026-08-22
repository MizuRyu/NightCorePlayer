import Foundation
import SwiftData

@Model
final class AllowanceEntity {
    @Attribute(.unique) var id: String = "default"

    var firstLaunchAt: Date
    var lastResetDayKey: String
    var remainingSeconds: Double
    var lastSeenAt: Date
    var rewardCountTotal: Int
    var proPromptShown: Bool

    init(
        firstLaunchAt: Date,
        lastResetDayKey: String,
        remainingSeconds: Double = Constants.Allowance.dailyFreeSeconds,
        lastSeenAt: Date,
        rewardCountTotal: Int = 0,
        proPromptShown: Bool = false
    ) {
        self.firstLaunchAt = firstLaunchAt
        self.lastResetDayKey = lastResetDayKey
        self.remainingSeconds = remainingSeconds
        self.lastSeenAt = lastSeenAt
        self.rewardCountTotal = rewardCountTotal
        self.proPromptShown = proPromptShown
    }
}
