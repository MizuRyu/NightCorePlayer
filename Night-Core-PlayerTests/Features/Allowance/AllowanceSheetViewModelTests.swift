import Testing
import Foundation
import Combine

@testable import Night_Core_Player

// MARK: - Stub

@MainActor
private final class AllowanceEnforcerStub: AllowanceEnforcer {
    private let eventSubject = PassthroughSubject<AllowanceEvent, Never>()
    var events: AnyPublisher<AllowanceEvent, Never> { eventSubject.eraseToAnyPublisher() }
    var isExhausted = false

    func tick(isPlaying: Bool, rate: Double, songID: String?, now: Date) {}
    func shouldStopAtSongBoundary() -> Bool { false }
    func shouldRevertToNormalRateNow() -> Bool { false }
    func markStoppedAtSongEnd() {}
    func markRevertedToNormalRate() {}

    func send(_ event: AllowanceEvent) {
        eventSubject.send(event)
    }
}

private struct SheetTestError: Error {}

// MARK: - Tests

@Suite("AllowanceSheetViewModel Tests")
@MainActor
struct AllowanceSheetViewModelTests {

    // MARK: - Helpers

    private static func setUp(
        entitlement: PlaybackEntitlement = .exhausted,
        shouldShowProPrompt: Bool = false,
        purchaseResult: Result<ProPurchaseOutcome, Error> = .success(.purchased),
        adService: RewardedAdServiceMock? = nil
    ) -> (
        vm: AllowanceSheetViewModel,
        enforcer: AllowanceEnforcerStub,
        allowanceMock: AllowanceServiceMock,
        storeMock: ProStoreServiceMock,
        nav: PlayerNavigator
    ) {
        let enforcer = AllowanceEnforcerStub()
        let allowanceMock = AllowanceServiceMock()
        allowanceMock.entitlementResult = entitlement
        allowanceMock.shouldShowProPromptResult = shouldShowProPrompt
        let storeMock = ProStoreServiceMock()
        storeMock.purchaseResult = purchaseResult
        let nav = PlayerNavigator()
        let vm = AllowanceSheetViewModel(
            allowanceEnforcer: enforcer,
            allowanceService: allowanceMock,
            proStoreService: storeMock,
            playerNavigator: nav,
            rewardedAdService: adService
        )
        return (vm, enforcer, allowanceMock, storeMock, nav)
    }

    private static func waitUntil(
        timeoutMilliseconds: Int = 1_000,
        pollMilliseconds: Int = 10,
        condition: @escaping @MainActor () -> Bool
    ) async {
        let attempts = max(1, timeoutMilliseconds / pollMilliseconds)
        for _ in 0..<attempts {
            if condition() { return }
            try? await Task.sleep(nanoseconds: UInt64(pollMilliseconds) * 1_000_000)
        }
    }

    // MARK: - Presentation

    @Test(".stoppedAtSongEndの受信でシートが表示されること")
    func stoppedAtSongEnd_presentsSheet() {
        // Given
        let (vm, enforcer, _, _, _) = Self.setUp()

        // When
        enforcer.send(.stoppedAtSongEnd)

        // Then
        #expect(vm.isPresented)
    }

    @Test(".exhaustedPendingSongEndではシートを表示しないこと")
    func exhaustedPendingSongEnd_doesNotPresentSheet() {
        // Given
        let (vm, enforcer, _, _, _) = Self.setUp()

        // When
        enforcer.send(.exhaustedPendingSongEnd)

        // Then
        #expect(!vm.isPresented)
    }

    @Test(".stoppedAtSongEndの受信で再生キューシートが閉じること（提示の排他）")
    func stoppedAtSongEnd_dismissesQueueSheet() {
        // Given
        let (vm, enforcer, _, _, nav) = Self.setUp()
        _ = vm  // sink が [weak self] のため VM を保持する
        nav.isQueuePresented = true

        // When
        enforcer.send(.stoppedAtSongEnd)

        // Then
        #expect(!nav.isQueuePresented, "AllowanceSheet提示時にキューシートは閉じる")
    }

    @Test("シート表示中に.stoppedAtSongEndを再受信すると、errorMessageとshowProPromptPitchがリセットされること")
    func stoppedAtSongEnd_whileAlreadyPresented_resetsErrorAndPitch() {
        // Given: Pro訴求を表示した状態
        let (vm, enforcer, allowanceMock, _, _) = Self.setUp(shouldShowProPrompt: true)
        enforcer.send(.stoppedAtSongEnd)
        vm.watchAdForReward()
        #expect(vm.showProPromptPitch)

        // When: grantRewardが失敗する状態でもう一度リワードを叩き、errorMessageを立てておく
        allowanceMock.grantRewardError = SheetTestError()
        vm.watchAdForReward()
        #expect(vm.errorMessage != nil)
        #expect(vm.showProPromptPitch, "エラーで訴求フラグは変化しない")

        // When: 別の枯渇で.stoppedAtSongEndを再受信（シートは表示中のまま再提示される）
        enforcer.send(.stoppedAtSongEnd)

        // Then
        #expect(vm.errorMessage == nil)
        #expect(!vm.showProPromptPitch)
        #expect(vm.isPresented)
    }

    // MARK: - Reward

    @Test("リワード視聴: grantRewardが呼ばれ、Pro訴求対象でなければシートが閉じること")
    func watchAdForReward_withoutProPrompt_closesSheet() {
        // Given
        let (vm, enforcer, allowanceMock, _, _) = Self.setUp(shouldShowProPrompt: false)
        enforcer.send(.stoppedAtSongEnd)
        #expect(vm.isPresented)

        // When
        vm.watchAdForReward()

        // Then
        #expect(allowanceMock.grantRewardCallCount == 1, "grantRewardが1回呼ばれる")
        #expect(!vm.isPresented, "訴求対象でなければ即座に閉じる")
        #expect(!vm.showProPromptPitch)
    }

    @Test("リワード視聴: Pro訴求対象ならmarkProPromptShownを先に保存し、成功した場合のみシートを閉じずに訴求を表示すること")
    func watchAdForReward_withProPrompt_savesFirstThenShowsPitch() {
        // Given
        let (vm, enforcer, allowanceMock, _, _) = Self.setUp(shouldShowProPrompt: true)
        enforcer.send(.stoppedAtSongEnd)

        // When
        vm.watchAdForReward()

        // Then
        #expect(vm.isPresented, "訴求を見せるためシートは開いたまま")
        #expect(vm.showProPromptPitch, "保存に成功したので訴求が表示される")
        #expect(allowanceMock.markProPromptShownCallCount == 1, "markProPromptShownは1回だけ呼ばれる")
    }

    @Test("リワード視聴: markProPromptShownが失敗したら訴求を表示せず、errorMessageにも出さないこと")
    func watchAdForReward_markProPromptShownFails_doesNotShowPitchOrUserError() {
        // Given: 保存自体が失敗する状態
        let (vm, enforcer, allowanceMock, _, _) = Self.setUp(shouldShowProPrompt: true)
        allowanceMock.markProPromptShownError = SheetTestError()
        enforcer.send(.stoppedAtSongEnd)

        // When
        vm.watchAdForReward()

        // Then: リワード自体は成功しているため、ユーザー向けエラーは出さず訴求も出さない
        #expect(!vm.showProPromptPitch, "保存失敗時に「生涯1回」の保証を破らないよう訴求を出さない")
        #expect(vm.errorMessage == nil, "保存失敗はログのみでユーザー向けエラーにしない")
    }

    @Test("Pro訴求は生涯1回だけ表示される（2回目のリワードでは再表示されない）")
    func watchAdForReward_calledTwice_showsProPromptOnlyOnce() {
        // Given: 1回目は訴求条件を満たす
        let (vm, enforcer, allowanceMock, _, _) = Self.setUp(shouldShowProPrompt: true)
        enforcer.send(.stoppedAtSongEnd)
        vm.watchAdForReward()
        #expect(vm.showProPromptPitch)
        #expect(allowanceMock.markProPromptShownCallCount == 1)

        // When: シートを閉じて再度枯渇し、もう一度リワードを視聴する
        vm.close()
        enforcer.send(.stoppedAtSongEnd)
        #expect(!vm.showProPromptPitch, "再提示時にリセットされる")

        vm.watchAdForReward()

        // Then: markProPromptShownは増えず、訴求も再表示されない
        #expect(!vm.showProPromptPitch, "生涯1回の訴求は2回目に表示されない")
        #expect(allowanceMock.markProPromptShownCallCount == 1, "markProPromptShownは生涯1回のまま")
        #expect(!vm.isPresented, "2回目は訴求対象外の通常フローとして閉じる")
    }

    @Test("リワード視聴: grantRewardがエラーならerrorMessageが設定されること")
    func watchAdForReward_grantRewardThrows_setsErrorMessage() {
        // Given
        let (vm, enforcer, allowanceMock, _, _) = Self.setUp()
        allowanceMock.grantRewardError = SheetTestError()
        enforcer.send(.stoppedAtSongEnd)

        // When
        vm.watchAdForReward()

        // Then
        #expect(vm.errorMessage != nil)
        #expect(vm.isPresented, "エラー時はシートを閉じない")
    }

    // MARK: - Reward Ad

    @Test("広告視聴に成功したらgrantRewardが呼ばれること")
    func watchAdForReward_adSucceeds_callsGrantReward() async throws {
        // Given
        let adMock = RewardedAdServiceMock()
        adMock.presentResult = .success(true)
        let (vm, enforcer, allowanceMock, _, _) = Self.setUp(adService: adMock)
        enforcer.send(.stoppedAtSongEnd)

        // When
        vm.watchAdForReward()
        await Self.waitUntil { allowanceMock.grantRewardCallCount == 1 }

        // Then
        #expect(adMock.presentCallCount == 1)
        #expect(allowanceMock.grantRewardCallCount == 1)
    }

    @Test("広告のロード失敗・在庫切れでも、無条件付与にフォールバックしgrantRewardが呼ばれること")
    func watchAdForReward_adUnavailable_stillGrantsReward() async throws {
        // Given
        let adMock = RewardedAdServiceMock()
        adMock.presentResult = .failure(RewardedAdError.notReady)
        let (vm, enforcer, allowanceMock, _, _) = Self.setUp(adService: adMock)
        enforcer.send(.stoppedAtSongEnd)

        // When
        vm.watchAdForReward()
        await Self.waitUntil { allowanceMock.grantRewardCallCount == 1 }

        // Then: ユーザーの落ち度ではないため広告なしで付与される
        #expect(allowanceMock.grantRewardCallCount == 1)
        #expect(vm.errorMessage == nil)
    }

    @Test("広告表示中に連打してもpresentCallCountは増えず、grantRewardも1回しか呼ばれないこと")
    func watchAdForReward_doubleTapWhileWatching_doesNotCallPresentTwice() async throws {
        // Given
        let adMock = RewardedAdServiceMock()
        adMock.presentResult = .success(true)
        adMock.presentDelayMilliseconds = 100
        let (vm, enforcer, allowanceMock, _, _) = Self.setUp(adService: adMock)
        enforcer.send(.stoppedAtSongEnd)

        // When
        vm.watchAdForReward()
        vm.watchAdForReward()
        await Self.waitUntil(timeoutMilliseconds: 2_000) { !vm.isWatchingAd }

        // Then
        #expect(adMock.presentCallCount == 1)
        #expect(allowanceMock.grantRewardCallCount == 1)
    }

    @Test("広告は表示されたが報酬条件を満たさなかった場合、付与してはいけないこと")
    func watchAdForReward_adPresentedButNotEarned_doesNotGrantReward() async throws {
        // Given
        let adMock = RewardedAdServiceMock()
        adMock.presentResult = .success(false)
        let (vm, enforcer, allowanceMock, _, _) = Self.setUp(adService: adMock)
        enforcer.send(.stoppedAtSongEnd)

        // When
        vm.watchAdForReward()
        await Self.waitUntil { !vm.isWatchingAd }

        // Then: 唯一「付与してはいけない」経路
        #expect(allowanceMock.grantRewardCallCount == 0)
        #expect(vm.isPresented, "報酬未達なのでシートは開いたまま")
    }

    @Test("present()が想定外のエラーをthrowしても、無条件付与にフォールバックすること")
    func watchAdForReward_presentThrowsUnexpectedError_stillGrantsReward() async throws {
        // Given
        let adMock = RewardedAdServiceMock()
        adMock.presentResult = .failure(SheetTestError())
        let (vm, enforcer, allowanceMock, _, _) = Self.setUp(adService: adMock)
        enforcer.send(.stoppedAtSongEnd)

        // When
        vm.watchAdForReward()
        await Self.waitUntil { allowanceMock.grantRewardCallCount == 1 }

        // Then
        #expect(allowanceMock.grantRewardCallCount == 1)
    }

    @Test("広告経由でgrantRewardがthrowしたらerrorMessageが設定され、isWatchingAdがfalseに戻ること")
    func watchAdForReward_grantRewardThrowsAfterAd_setsErrorAndResetsWatching() async throws {
        // Given
        let adMock = RewardedAdServiceMock()
        adMock.presentResult = .success(true)
        let (vm, enforcer, allowanceMock, _, _) = Self.setUp(adService: adMock)
        allowanceMock.grantRewardError = SheetTestError()
        enforcer.send(.stoppedAtSongEnd)

        // When
        vm.watchAdForReward()
        await Self.waitUntil { vm.errorMessage != nil }

        // Then
        #expect(vm.errorMessage != nil)
        #expect(!vm.isWatchingAd)
    }

    @Test("adServiceが未注入(nil)なら従来通り広告なしで直接grantRewardが呼ばれること")
    func watchAdForReward_noAdService_grantsRewardDirectly() {
        // Given
        let (vm, enforcer, allowanceMock, _, _) = Self.setUp(adService: nil)
        enforcer.send(.stoppedAtSongEnd)

        // When
        vm.watchAdForReward()

        // Then
        #expect(allowanceMock.grantRewardCallCount == 1)
        #expect(!vm.isPresented)
    }

    // MARK: - Purchase

    @Test("Pro購入: 購入成功でシートが閉じること")
    func purchasePro_success_closesSheet() async throws {
        // Given
        let (vm, enforcer, _, storeMock, _) = Self.setUp(purchaseResult: .success(.purchased))
        enforcer.send(.stoppedAtSongEnd)

        // When
        vm.purchasePro()
        await Self.waitUntil { storeMock.purchaseCallCount == 1 }

        // Then
        await Self.waitUntil { !vm.isPresented }
        #expect(!vm.isPresented)
        #expect(vm.errorMessage == nil)
    }

    @Test("Pro購入: キャンセルではシートを閉じないこと")
    func purchasePro_cancelled_keepsSheetOpen() async throws {
        // Given
        let (vm, enforcer, _, storeMock, _) = Self.setUp(purchaseResult: .success(.cancelled))
        enforcer.send(.stoppedAtSongEnd)

        // When
        vm.purchasePro()
        await Self.waitUntil { storeMock.purchaseCallCount == 1 }

        // Then
        #expect(vm.isPresented)
    }

    @Test("Pro購入: 商品を取得できない場合はエラーを表示しシートを閉じないこと")
    func purchasePro_unavailable_showsError() async throws {
        // Given: StoreKitから商品を取得できない状態
        let (vm, enforcer, _, _, _) = Self.setUp(purchaseResult: .success(.unavailable))
        enforcer.send(.stoppedAtSongEnd)

        // When
        vm.purchasePro()
        await Self.waitUntil { vm.errorMessage != nil }

        // Then: 無反応にせず理由を伝え、シートは開いたまま
        #expect(vm.errorMessage != nil)
        #expect(vm.isPresented)
    }

    @Test("Pro購入: 処理中はユーザー操作で閉じられないこと")
    func dismissByUser_whilePurchasing_keepsSheetOpen() async throws {
        // Given: 購入処理を遅延させ、処理中の窓を作る
        let (vm, enforcer, _, storeMock, _) = Self.setUp(purchaseResult: .success(.purchased))
        storeMock.purchaseDelayMilliseconds = 500
        enforcer.send(.stoppedAtSongEnd)

        // When: 処理中に閉じようとする
        vm.purchasePro()
        await Self.waitUntil { vm.isPurchasing }
        vm.dismissByUser()

        // Then: 裏で処理だけ進み結果が見えなくなるのを防ぐため閉じない
        #expect(vm.isPresented)
    }

    @Test("Pro購入: pendingではシートを閉じないこと")
    func purchasePro_pending_keepsSheetOpen() async throws {
        // Given
        let (vm, enforcer, _, storeMock, _) = Self.setUp(purchaseResult: .success(.pending))
        enforcer.send(.stoppedAtSongEnd)

        // When
        vm.purchasePro()
        await Self.waitUntil { storeMock.purchaseCallCount == 1 }

        // Then
        #expect(vm.isPresented)
    }

    @Test("Pro購入: エラーがシート内のerrorMessageに反映されること")
    func purchasePro_throws_setsErrorMessage() async throws {
        // Given
        let (vm, enforcer, _, _, _) = Self.setUp(purchaseResult: .failure(SheetTestError()))
        enforcer.send(.stoppedAtSongEnd)

        // When
        vm.purchasePro()
        await Self.waitUntil { vm.errorMessage != nil }

        // Then
        #expect(vm.errorMessage != nil)
        #expect(vm.isPresented, "エラー時はシートを閉じない")
    }

    // MARK: - Close

    @Test("閉じるボタン相当のclose()呼び出しでシートが閉じること")
    func close_dismissesSheet() {
        // Given
        let (vm, enforcer, _, _, _) = Self.setUp()
        enforcer.send(.stoppedAtSongEnd)
        #expect(vm.isPresented)

        // When
        vm.close()

        // Then
        #expect(!vm.isPresented)
    }

    // MARK: - Exhaustion Banner (#104)

    @Test(".exhaustedPendingSongEndの受信で枯渇バナーが表示されること")
    func exhaustedPendingSongEnd_showsExhaustionBanner() {
        // Given
        let (vm, enforcer, _, _, _) = Self.setUp()

        // When
        enforcer.send(.exhaustedPendingSongEnd)

        // Then: 曲末までの猶予中はシートを出さず、バナーだけで知らせる
        #expect(vm.isExhaustionBannerVisible)
        #expect(!vm.isPresented)
    }

    @Test(".stoppedAtSongEndの受信で枯渇バナーが消えること")
    func stoppedAtSongEnd_hidesExhaustionBanner() {
        // Given
        let (vm, enforcer, _, _, _) = Self.setUp()
        enforcer.send(.exhaustedPendingSongEnd)
        #expect(vm.isExhaustionBannerVisible)

        // When
        enforcer.send(.stoppedAtSongEnd)

        // Then
        #expect(!vm.isExhaustionBannerVisible)
    }

    @Test(".revertedToNormalRateの受信で枯渇バナーが消えること")
    func revertedToNormalRate_hidesExhaustionBanner() {
        // Given
        let (vm, enforcer, _, _, _) = Self.setUp()
        enforcer.send(.exhaustedPendingSongEnd)
        #expect(vm.isExhaustionBannerVisible)

        // When
        enforcer.send(.revertedToNormalRate)

        // Then
        #expect(!vm.isExhaustionBannerVisible)
    }

    @Test("枯渇バナーのタップで消えて「再生時間を追加」ダイアログが開くこと")
    func presentFromExhaustionBanner_hidesBannerAndOpensAddTimeDialog() {
        // Given
        let (vm, enforcer, _, _, _) = Self.setUp()
        enforcer.send(.exhaustedPendingSongEnd)
        #expect(vm.isExhaustionBannerVisible)

        // When
        vm.presentFromExhaustionBanner()

        // Then
        #expect(!vm.isExhaustionBannerVisible)
        #expect(vm.isPresented)
        #expect(vm.presentationReason == .addTime)
    }

    @Test("枯渇バナーの閉じるボタンでバナーだけが消え、シートは開かないこと")
    func dismissExhaustionBanner_hidesBannerOnly() {
        // Given
        let (vm, enforcer, _, _, _) = Self.setUp()
        enforcer.send(.exhaustedPendingSongEnd)
        #expect(vm.isExhaustionBannerVisible)

        // When
        vm.dismissExhaustionBanner()

        // Then
        #expect(!vm.isExhaustionBannerVisible)
        #expect(!vm.isPresented)
    }

    @Test("シート表示中は.exhaustedPendingSongEndを受けてもバナーを重ねて出さないこと")
    func exhaustedPendingSongEnd_whileDialogPresented_doesNotShowBanner() {
        // Given: 「再生時間を追加」ダイアログを開いた状態
        let (vm, enforcer, _, _, _) = Self.setUp()
        vm.presentForAddingTime()
        #expect(vm.isPresented)

        // When
        enforcer.send(.exhaustedPendingSongEnd)

        // Then: ダイアログとバナーの同時表示は避ける
        #expect(!vm.isExhaustionBannerVisible)
    }

    @Test("バナー表示中にpresentForAddingTime()を呼ぶとバナーが消えシートが開くこと")
    func presentForAddingTime_whileBannerVisible_hidesBannerAndOpensDialog() {
        // Given
        let (vm, enforcer, _, _, _) = Self.setUp()
        enforcer.send(.exhaustedPendingSongEnd)
        #expect(vm.isExhaustionBannerVisible)

        // When
        vm.presentForAddingTime()

        // Then: ダイアログが開いたらバナーは役目を終える
        #expect(!vm.isExhaustionBannerVisible)
        #expect(vm.isPresented)
    }

    @Test("バナー表示中にリワード付与が成功するとバナーが消えること")
    func grantRewardSucceeds_whileBannerVisible_hidesBanner() {
        // Given: ダイアログを開かせずバナーだけ出ている状態(設定画面等からの直接付与を模す)
        let (vm, enforcer, _, _, _) = Self.setUp(shouldShowProPrompt: false)
        enforcer.send(.exhaustedPendingSongEnd)
        #expect(vm.isExhaustionBannerVisible)

        // When: 残高が回復する
        vm.watchAdForReward()

        // Then
        #expect(!vm.isExhaustionBannerVisible)
    }

    @Test("バナー表示中にPro購入が成功するとバナーが消えること")
    func purchaseProSucceeds_whileBannerVisible_hidesBanner() async throws {
        // Given
        let (vm, enforcer, _, storeMock, _) = Self.setUp(purchaseResult: .success(.purchased))
        enforcer.send(.exhaustedPendingSongEnd)
        #expect(vm.isExhaustionBannerVisible)

        // When
        vm.purchasePro()
        await Self.waitUntil { storeMock.purchaseCallCount == 1 }
        await Self.waitUntil { !vm.isExhaustionBannerVisible }

        // Then
        #expect(!vm.isExhaustionBannerVisible)
    }
}
