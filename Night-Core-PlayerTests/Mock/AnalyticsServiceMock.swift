import Foundation
@testable import Night_Core_Player

@MainActor
final class AnalyticsServiceMock: AnalyticsService {
    private(set) var appLaunchedCallCount = 0
    private(set) var rewardGrantedViaAdValues: [Bool] = []
    private(set) var proPurchasedCallCount = 0
    private(set) var balanceDepletedCallCount = 0

    func appLaunched() {
        appLaunchedCallCount += 1
    }

    func rewardGranted(viaAd: Bool) {
        rewardGrantedViaAdValues.append(viaAd)
    }

    func proPurchased() {
        proPurchasedCallCount += 1
    }

    func balanceDepleted() {
        balanceDepletedCallCount += 1
    }
}
