import Foundation
import Combine
import Observation
import os

/// ダイアログを開いた理由。見出しの文言を状況に合わせるために持つ
enum AllowancePresentationReason: Equatable, Sendable {
    /// 再生中に残高が尽き、曲末で停止した
    case exhausted
    /// 残高がないまま倍速へ変更したため等速へ戻した
    case revertedToNormalRate
    /// 設定から能動的に時間を追加しにきた（枯渇していない場合もある）
    case addTime
}

@Observable
@MainActor
final class AllowanceSheetViewModel {
    private(set) var isPresented = false
    private(set) var isPurchasing = false
    private(set) var isWatchingAd = false
    private(set) var showProPromptPitch = false
    /// 残高が尽きた瞬間、曲末までの猶予を非モーダルで知らせるバナー。ADR-003の
    /// 「黙って猶予を与える」だけだった状態を解消する(#104)
    private(set) var isExhaustionBannerVisible = false
    private(set) var presentationReason: AllowancePresentationReason = .exhausted
    /// 今日あと何回リワードを受け取れるか。0 なら視聴ボタンを塞ぐ
    private(set) var rewardsRemainingToday = Constants.Allowance.dailyRewardLimit
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
                guard let self else { return }
                switch event {
                case .stoppedAtSongEnd:
                    present(reason: .exhausted)
                case .revertedToNormalRate:
                    // 無言で等速に戻ると理由が伝わらないため、その場で知らせる
                    present(reason: .revertedToNormalRate)
                case .exhaustedPendingSongEnd:
                    // 曲末まではADR-003の猶予どおり再生を続けるが、無言のままだと
                    // 「残高0でも再生できるバグ」に見えるため非モーダルバナーで知らせる。
                    // ダイアログが既に開いている間はバナーを重ねて出さない
                    guard !isPresented else { return }
                    isExhaustionBannerVisible = true
                }
            }
            .store(in: &cancellables)
    }

    /// 設定画面から能動的に再生時間を増やしたいときの導線。
    /// 枠超過を待たずに広告視聴と Pro 購入へ到達できるようにする
    func presentForAddingTime() {
        present(reason: .addTime)
    }

    /// 枯渇バナーのタップ。「再生時間を追加」ダイアログへ導線を繋ぐ
    /// (バナーはpresent(reason:)側で閉じる)
    func presentFromExhaustionBanner() {
        presentForAddingTime()
    }

    /// 枯渇バナー右端の閉じるボタン。自動タイムアウトはしない仕様のため明示操作でのみ消える
    func dismissExhaustionBanner() {
        isExhaustionBannerVisible = false
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
                    // Pro購入で残高制限そのものが外れるので枯渇バナーの案内は不要になる
                    isExhaustionBannerVisible = false
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
        refreshRewardsRemaining()
        // 残高が回復したので枯渇バナーの案内は不要になる
        isExhaustionBannerVisible = false

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
            present(reason: .exhausted)
        }
    #endif

    private func present(reason: AllowancePresentationReason) {
        errorMessage = nil
        showProPromptPitch = false
        presentationReason = reason
        refreshRewardsRemaining()
        isPresented = true
        // ダイアログが開いたらバナーは役目を終える(同時表示を避ける)
        isExhaustionBannerVisible = false
        // キューシートとの提示競合を避けるため排他にする
        playerNavigator.isQueuePresented = false
        // 「動画を見る」を押した瞬間に広告が出せるよう、開いた時点でロードしておく
        Task { await rewardedAdService?.preload() }
    }

    private func refreshRewardsRemaining() {
        rewardsRemainingToday = (try? allowanceService.rewardsRemainingToday(now: now()))
            ?? Constants.Allowance.dailyRewardLimit
    }
}
