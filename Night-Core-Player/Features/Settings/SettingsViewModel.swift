import SwiftUI
import Observation
import StoreKit
import NightCoreDomain

@Observable
@MainActor
final class SettingsViewModel {
    var defaultRate: Double
    var errorMessage: String?
    var infoMessage: String?
    private(set) var isPurchasing = false
    var isProEntitled: Bool { proStore?.isProEntitled ?? false }
    private(set) var proPriceText: String?

    /// 残高スナップショットの正規化を促す。表示は observable プロパティ経由で自動追随するが、
    /// 未ロード時と、停止中に日次リセット時刻を跨いだときは正規化の契機がないため明示的に呼ぶ
    func refreshAllowanceSnapshot() {
        _ = try? allowanceService?.entitlement(now: Date())
    }

    /// 残高欄の下に出す補足。制限が倍速再生だけに掛かることと、次に何が起きるかを伝える
    var allowanceDetailText: String {
        guard let allowanceService else { return "" }
        if isProEntitled {
            return String(localized: "Speed control has no time limit with Pro.")
        }
        guard let entitlement = allowanceService.observableEntitlement else { return "" }
        switch entitlement {
        case .trial(let endsAt):
            let date = endsAt.formatted(date: .abbreviated, time: .shortened)
            return String(localized: "Unlimited speed control until \(date).")
        case .free, .exhausted:
            return String(localized: "Normal speed is always free. The limit applies only to speed control, and resets daily.")
        }
    }

    /// 今日の残り再生時間の表示テキスト。Pro > トライアル > 無料残高/枯渇の優先順位で判定する
    var remainingTimeText: String {
        guard let allowanceService else { return "" }
        if isProEntitled {
            return String(localized: "Unlimited")
        }
        switch allowanceService.observableEntitlement {
        case .trial:
            return String(localized: "Trial in Progress")
        case .free(let remaining):
            return Self.formattedRemaining(remaining)
        case .exhausted:
            return Self.formattedRemaining(0)
        case nil:
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

    /// 秒まで出す。分単位に丸めると倍速再生中に減っていることが見えず、残高という概念が伝わらない。
    /// timeString(mm:ss固定)は再生時間表示（他機能）専用のため、60分超で「60:00」にならないここでは使わない
    private static func formattedRemaining(_ seconds: TimeInterval) -> String {
        Duration.seconds(max(0, seconds))
            .formatted(.time(pattern: seconds >= 3600 ? .hourMinuteSecond : .minuteSecond))
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
                case .unavailable:
                    errorMessage = String(localized: "Pro is not available right now. Please try again later.")
                case .purchased, .cancelled:
                    break
                }
            } catch {
                errorMessage = (error as? AppError)?.errorDescription ?? error.localizedDescription
            }
            await loadProState()
        }
    }

    #if DEBUG
        /// 検証用: 残高を使い切った状態にする。再生を試みると枠超過シート（リワード広告の入口）に到達する
        func debugExhaustAllowance() {
            applyDebugAllowanceChange(String(localized: "Allowance exhausted")) {
                try $0.debugExhaust(now: Date())
            }
        }

        /// 検証用: 残高の記録を消し、トライアルからやり直す
        func debugResetAllowance() {
            applyDebugAllowanceChange(String(localized: "Allowance reset")) {
                try $0.debugReset()
            }
        }

        private func applyDebugAllowanceChange(
            _ message: String,
            _ change: (AllowanceService) throws -> Void
        ) {
            guard let allowanceService else { return }
            do {
                try change(allowanceService)
                // debugReset は記録ごと消すため、表示のために再ロードが必要
                refreshAllowanceSnapshot()
                infoMessage = message
            } catch {
                errorMessage = (error as? AppError)?.errorDescription ?? error.localizedDescription
            }
        }
    #endif

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
