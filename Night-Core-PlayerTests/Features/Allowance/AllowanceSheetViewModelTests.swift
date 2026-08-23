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

    func tick(isPlaying: Bool, rate: Double, now: Date) {}
    func shouldStopAtSongBoundary() -> Bool { false }
    func markStoppedAtSongEnd() {}

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
        purchaseResult: Result<ProPurchaseOutcome, Error> = .success(.purchased)
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
            playerNavigator: nav
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
}
