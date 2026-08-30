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
    /// 残高がないまま倍速へ変更して等速へ戻されたときは、見出しで理由を伝える
    private(set) var didRevertToNormalRate = false
    var errorMessage: String?

    private let allowanceService: AllowanceService
    private let proStoreService: ProStoreService
    private let rewardedAdService: RewardedAdService?
    private let playerNavigator: PlayerNavigator
    private let musicPlayerService: MusicPlayerService?
    private let now: () -> Date
    private let logger = Logger(subsystem: Constants.Logging.subsystem, category: "Allowance")
    private var cancellables: Set<AnyCancellable> = []

    init(
        allowanceEnforcer: AllowanceEnforcer,
        allowanceService: AllowanceService,
        proStoreService: ProStoreService,
        playerNavigator: PlayerNavigator,
        rewardedAdService: RewardedAdService? = nil,
        musicPlayerService: MusicPlayerService? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.allowanceService = allowanceService
        self.proStoreService = proStoreService
        self.rewardedAdService = rewardedAdService
        self.playerNavigator = playerNavigator
        self.musicPlayerService = musicPlayerService
        self.now = now
        // AllowanceEnforcerは@MainActor隔離のため、eventsの発行元は既にメインスレッド。receive(on:)によるhopは不要
        allowanceEnforcer.events
            .sink { [weak self] event in
                switch event {
                case .stoppedAtSongEnd:
                    self?.present(revertedToNormalRate: false)
                case .revertedToNormalRate:
                    // 無言で等速に戻ると理由が伝わらないため、その場で知らせる
                    self?.present(revertedToNormalRate: true)
                case .exhaustedPendingSongEnd:
                    break
                }
            }
            .store(in: &cancellables)
    }

    /// 設定画面から能動的に再生時間を増やしたいときの導線。
    /// 枠超過を待たずに広告視聴と Pro 購入へ到達できるようにする
    func presentForAddingTime() {
        present(revertedToNormalRate: false)
    }

    /// 広告視聴中・購入中
    var isBusy: Bool { isWatchingAd || isPurchasing }

    /// 閉じるボタン・背景タップからの明示的な操作。処理中は結果もエラーも見えなくなるため塞ぐ
    /// （購入成功後の自動クローズは処理中に呼ばれるため close() を使う）
    func dismissByUser() {
        guard !isBusy else { return }
        close()
    }

    func close() {
        isPresented = false
    }

    func watchAdForReward() {
        guard !isBusy else { return }
        errorMessage = nil

        guard let rewardedAdService else {
            grantRewardAndProceed()
            return
        }

        isWatchingAd = true
        Task {
            defer { isWatchingAd = false }
            do {
                // 広告が出せない場合はエラーがthrowされ、下のcatchで無条件付与にフォールバックする
                guard try await rewardedAdService.present() else { return }
                grantRewardAndProceed()
            } catch {
                // ロード失敗・在庫切れ・表示失敗はユーザーの落ち度ではないため、広告なしで付与する。#68の計測用にログを残す
                logger.error("Rewarded ad unavailable, granting reward without ad: \(error.localizedDescription)")
                grantRewardAndProceed()
            }
        }
    }

    func purchasePro() {
        errorMessage = nil
        Task {
            guard !isBusy else { return }
            isPurchasing = true
            defer { isPurchasing = false }
            do {
                switch try await proStoreService.purchase() {
                case .purchased:
                    close()
                case .unavailable:
                    errorMessage = String(localized: "Pro is not available right now. Please try again later.")
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

        // 境界停止で等速に戻された再生を、停止前の倍速で自動再開する (#87)
        if let musicPlayerService {
            Task { await musicPlayerService.resumeAfterRewardGrant() }
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

    #if DEBUG
        /// 検証用: 曲末の停止を待たずに枠超過シートを開く。リワード広告の実機確認に使う
        func debugPresent() {
            present(revertedToNormalRate: false)
        }
    #endif

    private func present(revertedToNormalRate: Bool) {
        errorMessage = nil
        showProPromptPitch = false
        didRevertToNormalRate = revertedToNormalRate
        isPresented = true
        // キューシートとの提示競合を避けるため排他にする
        playerNavigator.isQueuePresented = false
    }
}
