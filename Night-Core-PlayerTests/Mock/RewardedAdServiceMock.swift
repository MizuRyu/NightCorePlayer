import Foundation
import NightCoreDomain
@testable import Night_Core_Player

@MainActor
final class RewardedAdServiceMock: RewardedAdService {
    var presentResult: Result<Bool, Error> = .success(true)
    /// isWatchingAd中の多重タップテスト用にpresent()の完了を遅らせる
    var presentDelayMilliseconds: Int = 0

    private(set) var presentCallCount = 0
    private(set) var preloadCallCount = 0

    func preload() async {
        preloadCallCount += 1
    }

    func present() async throws -> Bool {
        presentCallCount += 1
        if presentDelayMilliseconds > 0 {
            try? await Task.sleep(nanoseconds: UInt64(presentDelayMilliseconds) * 1_000_000)
        }
        return try presentResult.get()
    }
}
