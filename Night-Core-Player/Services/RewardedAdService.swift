import Foundation
import GoogleMobileAds
import UIKit
import os

// MARK: - Error

/// present()時にロード未完了・在庫切れだった場合に投げる。呼び出し側は無条件付与にフォールバックする
enum RewardedAdError: Error {
    case notReady
}

// MARK: - Protocol

@MainActor
protocol RewardedAdService: Sendable {
    var isReady: Bool { get }
    func preload() async
    func present() async throws -> Bool
}

// MARK: - Impl

@MainActor
final class RewardedAdServiceImpl: NSObject, RewardedAdService {
    private let adUnitID: String
    private let logger = Logger(subsystem: Constants.Logging.subsystem, category: "Ads")

    private var rewardedAd: RewardedAd?
    private var isLoading = false
    private var rewardEarned = false
    private var dismissContinuation: CheckedContinuation<Bool, Never>?

    init(adUnitID: String = Constants.Ads.rewardedUnitID) {
        self.adUnitID = adUnitID
    }

    var isReady: Bool { rewardedAd != nil }

    func preload() async {
        guard rewardedAd == nil, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let ad = try await RewardedAd.load(with: adUnitID, request: Request())
            ad.fullScreenContentDelegate = self
            rewardedAd = ad
        } catch {
            logger.error("Rewarded ad preload failed: \(error.localizedDescription)")
        }
    }

    func present() async throws -> Bool {
        if rewardedAd == nil {
            await preload()
        }
        guard let ad = rewardedAd, let rootViewController = Self.topViewController() else {
            throw RewardedAdError.notReady
        }
        rewardedAd = nil
        rewardEarned = false

        return await withCheckedContinuation { continuation in
            self.dismissContinuation = continuation
            ad.present(from: rootViewController) { [weak self] in
                self?.rewardEarned = true
            }
        }
    }

    // MARK: - Private

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
            ?? scenes.first as? UIWindowScene
        guard let windowScene else { return nil }
        let root = windowScene.windows.first { $0.isKeyWindow }?.rootViewController
            ?? windowScene.windows.first?.rootViewController
        guard let root else { return nil }
        return topMost(from: root)
    }

    private static func topMost(from viewController: UIViewController) -> UIViewController {
        if let presented = viewController.presentedViewController {
            return topMost(from: presented)
        }
        if let nav = viewController as? UINavigationController, let visible = nav.visibleViewController {
            return topMost(from: visible)
        }
        if let tab = viewController as? UITabBarController, let selected = tab.selectedViewController {
            return topMost(from: selected)
        }
        return viewController
    }
}

// MARK: - FullScreenContentDelegate

extension RewardedAdServiceImpl: FullScreenContentDelegate {
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        logger.error("Rewarded ad failed to present: \(error.localizedDescription)")
        dismissContinuation?.resume(returning: false)
        dismissContinuation = nil
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        dismissContinuation?.resume(returning: rewardEarned)
        dismissContinuation = nil
        Task { await preload() }
    }
}
