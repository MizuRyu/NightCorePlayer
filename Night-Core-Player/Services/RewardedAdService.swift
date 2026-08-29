import Foundation
import GoogleMobileAds
import os

// MARK: - Error

/// present()が失敗した場合に投げる。呼び出し側はいずれも無条件付与にフォールバックする
enum RewardedAdError: Error {
    /// ロード未完了・在庫切れ
    case notReady
    /// SDKからのpresent失敗、またはdismissコールバック未着によるタイムアウト
    case presentFailed
    /// present()の多重呼び出し
    case alreadyPresenting
}

// MARK: - Protocol

@MainActor
protocol RewardedAdService: Sendable {
    func preload() async
    func present() async throws -> Bool
}

// MARK: - Impl

@MainActor
final class RewardedAdServiceImpl: NSObject, RewardedAdService {
    /// ロード完了を待つ上限。AdMobのロードは通常数秒で終わるため、タップ直後の在庫切れ判定を遅らせすぎない値にする
    private static let loadTimeoutNanoseconds: UInt64 = 15_000_000_000
    /// dismiss通知を待つ上限。リワード動画+エンドカードの実視聴時間を大きく超え、
    /// 通常操作では発火しない値にしつつ、コールバック未着時にisWatchingAdが永久に固定されるのを防ぐ
    private static let dismissTimeoutNanoseconds: UInt64 = 300_000_000_000

    private let adUnitID: String
    private let logger = Logger(subsystem: Constants.Logging.subsystem, category: "Ads")

    private var rewardedAd: RewardedAd?
    // fullScreenContentDelegateはSDK側でweakなため、表示中に広告オブジェクトが解放されるとコールバックが飛ばない。
    // 表示が終わるまでここで強参照する
    private var presentingAd: RewardedAd?
    private var loadTask: Task<RewardedAd, Error>?
    private var rewardEarned = false
    private var dismissContinuation: CheckedContinuation<Bool, Error>?

    init(adUnitID: String = Constants.Ads.rewardedUnitID) {
        self.adUnitID = adUnitID
    }

    func preload() async {
        guard rewardedAd == nil else { return }
        do {
            _ = try await awaitLoad(currentLoadTask(), timeoutNanoseconds: Self.loadTimeoutNanoseconds)
        } catch {
            logger.error("Rewarded ad preload failed: \(error.localizedDescription)")
        }
    }

    func present() async throws -> Bool {
        guard dismissContinuation == nil else {
            throw RewardedAdError.alreadyPresenting
        }

        let ad: RewardedAd
        if let cached = rewardedAd {
            ad = cached
        } else {
            do {
                ad = try await awaitLoad(currentLoadTask(), timeoutNanoseconds: Self.loadTimeoutNanoseconds)
            } catch {
                throw RewardedAdError.notReady
            }
        }
        rewardedAd = nil
        presentingAd = ad
        rewardEarned = false

        return try await withCheckedThrowingContinuation { continuation in
            dismissContinuation = continuation
            // rootViewControllerにnilを渡すとSDKがキーウィンドウの最上位VCを解決する。解決不能時はdidFailToPresent経由で扱う
            ad.present(from: nil) { [weak self] in
                self?.rewardEarned = true
            }
            scheduleDismissTimeout()
        }
    }

    // MARK: - Private

    private func currentLoadTask() -> Task<RewardedAd, Error> {
        if let loadTask { return loadTask }
        let task = Task<RewardedAd, Error> {
            do {
                let ad = try await RewardedAd.load(with: self.adUnitID, request: Request())
                ad.fullScreenContentDelegate = self
                self.rewardedAd = ad
                self.loadTask = nil
                return ad
            } catch {
                self.loadTask = nil
                throw error
            }
        }
        loadTask = task
        return task
    }

    /// タイムアウトしても元のtaskはキャンセルせず、バックグラウンドで完走させて次回以降のキャッシュに残す
    private func awaitLoad(
        _ task: Task<RewardedAd, Error>,
        timeoutNanoseconds: UInt64
    ) async throws -> RewardedAd {
        try await withThrowingTaskGroup(of: RewardedAd.self) { group in
            group.addTask { try await task.value }
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
                throw RewardedAdError.notReady
            }
            defer { group.cancelAll() }
            guard let result = try await group.next() else {
                throw RewardedAdError.notReady
            }
            return result
        }
    }

    private func scheduleDismissTimeout() {
        Task {
            try? await Task.sleep(nanoseconds: Self.dismissTimeoutNanoseconds)
            guard let continuation = dismissContinuation else { return }
            dismissContinuation = nil
            presentingAd = nil
            logger.error("Rewarded ad dismiss callback timed out")
            continuation.resume(throwing: RewardedAdError.presentFailed)
        }
    }
}

// MARK: - FullScreenContentDelegate

extension RewardedAdServiceImpl: FullScreenContentDelegate {
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        logger.error("Rewarded ad failed to present: \(error.localizedDescription)")
        presentingAd = nil
        dismissContinuation?.resume(throwing: RewardedAdError.presentFailed)
        dismissContinuation = nil
        Task { await preload() }
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        presentingAd = nil
        dismissContinuation?.resume(returning: rewardEarned)
        dismissContinuation = nil
        Task { await preload() }
    }
}
