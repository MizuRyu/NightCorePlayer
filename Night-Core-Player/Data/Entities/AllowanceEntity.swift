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
    // 既存ユーザーのDBを軽量マイグレーションで読めるよう、宣言側にデフォルト値を持たせる
    var rewardCountToday: Int = 0
    var proPromptShown: Bool

    init(
        firstLaunchAt: Date,
        nextResetAt: Date,
        remainingSeconds: Double = Constants.Allowance.dailyFreeSeconds,
        lastSeenAt: Date,
        rewardCountTotal: Int = 0,
        rewardCountToday: Int = 0,
        proPromptShown: Bool = false
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
