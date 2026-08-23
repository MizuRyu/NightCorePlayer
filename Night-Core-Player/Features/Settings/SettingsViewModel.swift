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

    private let rateManager: PlaybackRateManager
    private let playerService: MusicPlayerService
    private let proStore: ProStoreService?

    init(
        rateManager: PlaybackRateManager,
        playerService: MusicPlayerService,
        proStore: ProStoreService? = nil
    ) {
        self.rateManager = rateManager
        self.playerService = playerService
        self.proStore = proStore
        self.defaultRate = rateManager.defaultRate
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
