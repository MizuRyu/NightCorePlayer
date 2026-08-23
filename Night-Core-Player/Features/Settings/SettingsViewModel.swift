import SwiftUI
import Observation
import StoreKit

@Observable
@MainActor
final class SettingsViewModel {
    var defaultRate: Double
    var errorMessage: String?
    var infoMessage: String?
    private(set) var isPurchasing = false
    var isProEntitled: Bool { proStore?.isProEntitled ?? false }
    private(set) var proPriceText: String?

    /// 今日の残り再生時間の表示テキスト。Pro > トライアル > 無料残高/枯渇の優先順位で判定する
    var remainingTimeText: String {
        guard let allowanceService else { return "" }
        if isProEntitled {
            return String(localized: "Unlimited")
        }
        do {
            switch try allowanceService.entitlement(now: Date()) {
            case .trial:
                return String(localized: "Trial in Progress")
            case .free(let remaining):
                return Self.formattedRemaining(remaining)
            case .exhausted:
                return Self.formattedRemaining(0)
            }
        } catch {
            return ""
        }
    }

    private let rateManager: PlaybackRateManager
    private let playerService: MusicPlayerService
    private let proStore: ProStoreService?
    private let allowanceService: AllowanceService?

    init(
        rateManager: PlaybackRateManager,
        playerService: MusicPlayerService,
        proStore: ProStoreService? = nil,
        allowanceService: AllowanceService? = nil
    ) {
        self.rateManager = rateManager
        self.playerService = playerService
        self.proStore = proStore
        self.allowanceService = allowanceService
        self.defaultRate = rateManager.defaultRate
    }

    /// 時間単位に丸める。timeString(mm:ss固定)は再生時間表示（他機能）専用のため、60分超で「60:00」にならないここでは使わない
    private static func formattedRemaining(_ seconds: TimeInterval) -> String {
        Duration.seconds(max(0, seconds)).formatted(.units(allowed: [.hours, .minutes], width: .narrow))
    }

    func updateDefaultRate(to rate: Double) {
        let clamped = min(
            max(rate, Constants.MusicPlayer.minPlaybackRate),
            Constants.MusicPlayer.maxPlaybackRate
        )
        defaultRate = clamped
        Task {
            do {
                try rateManager.setDefaultRate(clamped)
            } catch {
                errorMessage = (error as? AppError)?.errorDescription ?? error.localizedDescription
            }
            await playerService.setSessionRate(clamped)
        }
    }

    /// 表示価格とPro状態の取得。SettingsのProセクション表示時に呼ぶ
    func loadProState() async {
        guard let proStore else { return }
        if proPriceText == nil {
            proPriceText = await proStore.loadProduct()?.displayPrice
        }
    }

    func purchasePro() {
        Task {
            guard !isPurchasing else { return }
            guard let proStore else { return }
            isPurchasing = true
            defer { isPurchasing = false }
            do {
                switch try await proStore.purchase() {
                case .pending:
                    infoMessage = String(localized: "Purchase pending approval")
                case .purchased, .cancelled:
                    break
                }
            } catch {
                errorMessage = (error as? AppError)?.errorDescription ?? error.localizedDescription
            }
            await loadProState()
        }
    }

    func restorePro() {
        Task {
            guard !isPurchasing else { return }
            guard let proStore else { return }
            isPurchasing = true
            defer { isPurchasing = false }
            do {
                try await proStore.restore()
            } catch {
                errorMessage = (error as? AppError)?.errorDescription ?? error.localizedDescription
            }
            await loadProState()
        }
    }
}
