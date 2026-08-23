import Foundation
import Combine
import Observation
import os

@Observable
@MainActor
final class AllowanceSheetViewModel {
    private(set) var isPresented = false
    private(set) var isPurchasing = false
    private(set) var isWatchingAd = false
    private(set) var showProPromptPitch = false
    var errorMessage: String?

    private let allowanceService: AllowanceService
    private let proStoreService: ProStoreService
    private let rewardedAdService: RewardedAdService?
    private let playerNavigator: PlayerNavigator
    private let now: () -> Date
    private let logger = Logger(subsystem: Constants.Logging.subsystem, category: "Allowance")
    private var cancellables: Set<AnyCancellable> = []

    init(
        allowanceEnforcer: AllowanceEnforcer,
        allowanceService: AllowanceService,
        proStoreService: ProStoreService,
        playerNavigator: PlayerNavigator,
        rewardedAdService: RewardedAdService? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.allowanceService = allowanceService
        self.proStoreService = proStoreService
        self.rewardedAdService = rewardedAdService
        self.playerNavigator = playerNavigator
        self.now = now
        // AllowanceEnforcerは@MainActor隔離のため、eventsの発行元は既にメインスレッド。receive(on:)によるhopは不要
        allowanceEnforcer.events
            .sink { [weak self] event in
                guard case .stoppedAtSongEnd = event else { return }
                self?.present()
            }
            .store(in: &cancellables)
    }

    func close() {
        isPresented = false
    }

    func watchAdForReward() {
        guard !isWatchingAd else { return }
        errorMessage = nil

        guard let rewardedAdService else {
            grantRewardAndProceed()
            return
        }

        isWatchingAd = true
        Task {
            defer { isWatchingAd = false }
            do {
                // 広告が出せない場合はnotReadyがthrowされ、下のcatchで無条件付与にフォールバックする
                guard try await rewardedAdService.present() else { return }
                grantRewardAndProceed()
            } catch {
                // ロード失敗・在庫切れはユーザーの落ち度ではないため、広告なしで付与する
                grantRewardAndProceed()
            }
        }
    }

    func purchasePro() {
        errorMessage = nil
        Task {
            guard !isPurchasing else { return }
            isPurchasing = true
            defer { isPurchasing = false }
            do {
                switch try await proStoreService.purchase() {
                case .purchased:
                    close()
                case .cancelled, .pending:
                    break
                }
            } catch {
                errorMessage = (error as? AppError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    // MARK: - Private

    private func grantRewardAndProceed() {
        errorMessage = nil
        do {
            _ = try allowanceService.grantReward(now: now())
        } catch {
            errorMessage = (error as? AppError)?.errorDescription ?? error.localizedDescription
            return
        }

        let shouldShowPrompt: Bool
        do {
            shouldShowPrompt = try allowanceService.shouldShowProPrompt(now: now())
        } catch {
            errorMessage = (error as? AppError)?.errorDescription ?? error.localizedDescription
            return
        }
        guard shouldShowPrompt else {
            close()
            return
        }

        // markProPromptShownを先に実行し、保存に成功した場合のみ訴求を表示する。
        // 保存失敗時に訴求だけ出すと「生涯1回」の保証が破れるため
        do {
            try allowanceService.markProPromptShown(now: now())
            showProPromptPitch = true
        } catch {
            // リワード自体は成功しているためユーザー向けエラーにはしない
            logger.error("markProPromptShown failed: \(error.localizedDescription)")
            close()
        }
    }

    private func present() {
        errorMessage = nil
        showProPromptPitch = false
        isPresented = true
        // キューシートとの提示競合を避けるため排他にする
        playerNavigator.isQueuePresented = false
    }
}
