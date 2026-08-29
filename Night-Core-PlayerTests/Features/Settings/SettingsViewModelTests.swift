import Testing
import Foundation

@testable import Night_Core_Player

// MARK: - Mock

final class PlaybackRateManagerMock: PlaybackRateManager {
    var defaultRate: Double = Constants.MusicPlayer.defaultPlaybackRate
    private(set) var setDefaultRateArgs: [Double] = []
    func setDefaultRate(_ rate: Double) throws {
        setDefaultRateArgs.append(rate)
        defaultRate = rate
    }
}

private struct PurchaseTestError: Error {}

// MARK: - Tests

@Suite("SettingsViewModel Tests", .serialized)
@MainActor
struct SettingsViewModelTests {

    // MARK: - Helpers

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

    private static func setUp(
        proStore: ProStoreService? = nil,
        allowanceService: AllowanceService? = nil
    ) -> (
        vm: SettingsViewModel,
        rateMock: PlaybackRateManagerMock,
        svcMock: MusicPlayerServiceMock
    ) {
        let rateMock = PlaybackRateManagerMock()
        let svcMock = MusicPlayerServiceMock()
        let vm = SettingsViewModel(
            rateManager: rateMock,
            playerService: svcMock,
            proStore: proStore,
            allowanceService: allowanceService
        )
        return (vm, rateMock, svcMock)
    }

    // MARK: - Tests

    @Test("初期化: rateManagerのdefaultRateがViewModelに反映されること")
    func init_default_syncsRateFromManager() {
        // Given
        let (vm, rateMock, _) = SettingsViewModelTests.setUp()

        // Then
        #expect(
            vm.defaultRate == rateMock.defaultRate,
            "初期値がrateManagerのdefaultRateと一致する"
        )
        #expect(
            vm.defaultRate == Constants.MusicPlayer.defaultPlaybackRate,
            "初期値がデフォルト再生速度と一致する"
        )
    }

    @Test("updateDefaultRate: rateManagerとplayerServiceに反映されること")
    func updateDefaultRate_validValue_propagatesToAll() async throws {
        // Given
        let (vm, rateMock, svcMock) = SettingsViewModelTests.setUp()

        // When
        vm.updateDefaultRate(to: 1.8)
        await SettingsViewModelTests.waitUntil {
            rateMock.setDefaultRateArgs.count == 1 && svcMock.rateArgs.count == 1
        }

        // Then
        #expect(rateMock.setDefaultRateArgs.count == 1, "setDefaultRateが1回呼ばれる")
        #expect(rateMock.setDefaultRateArgs.first == 1.8, "値が1.8で渡される")
        #expect(svcMock.rateArgs.count == 1, "setSessionRateが1回呼ばれる")
        #expect(svcMock.rateArgs.first == 1.8, "sessionRateも1.8")
        #expect(vm.defaultRate == 1.8, "ViewModelのdefaultRateが1.8")
    }

    @Test("updateDefaultRate: 最大値を超える値がクランプされること")
    func updateDefaultRate_exceedsMax_clampedToMax() async throws {
        // Given
        let (vm, rateMock, svcMock) = SettingsViewModelTests.setUp()
        let maxRate = Constants.MusicPlayer.maxPlaybackRate

        // When
        vm.updateDefaultRate(to: 100.0)
        await SettingsViewModelTests.waitUntil {
            vm.defaultRate == maxRate && rateMock.setDefaultRateArgs.count == 1
        }

        // Then
        #expect(vm.defaultRate == maxRate, "ViewModelのdefaultRateがmaxにクランプ")
        #expect(rateMock.setDefaultRateArgs.first == maxRate, "rateManagerにクランプ後の値が渡される")
        #expect(svcMock.rateArgs.first == maxRate, "playerServiceにクランプ後の値が渡される")
    }

    @Test("updateDefaultRate: 最小値を下回る値がクランプされること")
    func updateDefaultRate_belowMin_clampedToMin() async throws {
        // Given
        let (vm, rateMock, svcMock) = SettingsViewModelTests.setUp()
        let minRate = Constants.MusicPlayer.minPlaybackRate

        // When
        vm.updateDefaultRate(to: 0.01)
        await SettingsViewModelTests.waitUntil {
            vm.defaultRate == minRate && rateMock.setDefaultRateArgs.count == 1
        }

        // Then
        #expect(vm.defaultRate == minRate, "ViewModelのdefaultRateがminにクランプ")
        #expect(rateMock.setDefaultRateArgs.first == minRate, "rateManagerにクランプ後の値が渡される")
        #expect(svcMock.rateArgs.first == minRate, "playerServiceにクランプ後の値が渡される")
    }

    // MARK: - Pro Store

    @Test("purchasePro: purchase()がthrowしたらerrorMessageが設定されること")
    func purchasePro_purchaseThrows_setsErrorMessage() async throws {
        // Given
        let storeMock = ProStoreServiceMock()
        storeMock.purchaseResult = .failure(PurchaseTestError())
        let (vm, _, _) = SettingsViewModelTests.setUp(proStore: storeMock)

        // When
        vm.purchasePro()
        await SettingsViewModelTests.waitUntil { vm.errorMessage != nil }

        // Then
        #expect(vm.errorMessage != nil, "エラーメッセージが設定される")
        #expect(vm.infoMessage == nil, "情報メッセージは設定されない")
    }

    @Test("purchasePro: 購入成功後にisProEntitledがtrueになること")
    func purchasePro_purchaseSucceeds_entitlesPro() async throws {
        // Given
        let storeMock = ProStoreServiceMock()
        storeMock.purchaseResult = .success(.purchased)
        storeMock.entitledResult = true
        let (vm, _, _) = SettingsViewModelTests.setUp(proStore: storeMock)

        // When
        vm.purchasePro()
        await SettingsViewModelTests.waitUntil { vm.isProEntitled }

        // Then
        #expect(vm.isProEntitled, "購入成功後にPro権限が有効になる")
        #expect(vm.errorMessage == nil)
    }

    @Test("purchasePro: 商品を取得できない場合はエラーを表示すること")
    func purchasePro_productUnavailable_showsError() async throws {
        // Given: StoreKitから商品を取得できない状態
        let storeMock = ProStoreServiceMock()
        storeMock.purchaseResult = .success(.unavailable)
        let (vm, _, _) = SettingsViewModelTests.setUp(proStore: storeMock)

        // When
        vm.purchasePro()
        await SettingsViewModelTests.waitUntil { vm.errorMessage != nil }

        // Then: 無反応にせず、取得できなかったことを伝える
        #expect(vm.errorMessage != nil, "ユーザーのキャンセルと区別してエラーを出す")
        #expect(!vm.isProEntitled)
    }

    @Test("purchasePro: ユーザーキャンセルではエラーを表示しないこと")
    func purchasePro_cancelled_doesNotShowError() async throws {
        // Given
        let storeMock = ProStoreServiceMock()
        storeMock.purchaseResult = .success(.cancelled)
        let (vm, _, _) = SettingsViewModelTests.setUp(proStore: storeMock)

        // When
        vm.purchasePro()
        await SettingsViewModelTests.waitUntil { !vm.isPurchasing }

        // Then
        #expect(vm.errorMessage == nil, "ユーザー自身の操作にはエラーを出さない")
    }

    @Test("purchasePro: isPurchasing中の再呼び出しはpurchase()を実行しないこと")
    func purchasePro_whilePurchasing_skipsSecondCall() async throws {
        // Given: purchase()を遅延させ、処理中の窓を作る
        let storeMock = ProStoreServiceMock()
        storeMock.purchaseResult = .success(.purchased)
        storeMock.entitledResult = true
        storeMock.purchaseDelayMilliseconds = 500
        let (vm, _, _) = SettingsViewModelTests.setUp(proStore: storeMock)

        // When: 1回目を実行し、処理中に2回目を呼ぶ
        vm.purchasePro()
        await SettingsViewModelTests.waitUntil { vm.isPurchasing }
        let countDuringFirst = storeMock.purchaseCallCount
        vm.purchasePro()

        // Then: 2回目は無視され、purchase()は1回だけ実行される
        #expect(storeMock.purchaseCallCount == countDuringFirst, "処理中の再呼び出しでpurchase()が増えない")
        await SettingsViewModelTests.waitUntil { !vm.isPurchasing }
        #expect(storeMock.purchaseCallCount == 1, "purchase()は1回だけ実行される")
    }

    @Test("proStoreなし: loadProState()/purchasePro()が無害に終了すること")
    func withoutProStore_callsAreHarmless() async throws {
        // Given
        let (vm, _, _) = SettingsViewModelTests.setUp()

        // When
        await vm.loadProState()
        vm.purchasePro()

        // Then: エラー・情報・状態変化は起きない
        await SettingsViewModelTests.waitUntil { !vm.isPurchasing }
        #expect(!vm.isProEntitled, "Pro権限は無効のまま")
        #expect(vm.proPriceText == nil, "価格は読み込まれない")
        #expect(vm.errorMessage == nil)
        #expect(vm.infoMessage == nil)
    }

    // MARK: - Allowance

    @Test("remainingTimeText: Pro権限があれば無制限と表示されること")
    func remainingTimeText_proEntitled_showsUnlimited() {
        // Given
        let storeMock = ProStoreServiceMock()
        storeMock.entitledResult = true
        let allowanceMock = AllowanceServiceMock()
        allowanceMock.entitlementResult = .free(remaining: 0)
        let (vm, _, _) = SettingsViewModelTests.setUp(proStore: storeMock, allowanceService: allowanceMock)

        // Then
        #expect(vm.remainingTimeText == String(localized: "Unlimited"))
    }

    @Test("remainingTimeText: トライアル中はTrial in Progressと表示されること")
    func remainingTimeText_trial_showsTrialInProgress() {
        // Given
        let allowanceMock = AllowanceServiceMock()
        allowanceMock.entitlementResult = .trial(endsAt: Date().addingTimeInterval(86400))
        let (vm, _, _) = SettingsViewModelTests.setUp(allowanceService: allowanceMock)

        // Then
        #expect(vm.remainingTimeText == String(localized: "Trial in Progress"))
    }

    @Test("remainingTimeText: 残高3600秒は「60:00」ではなく時間単位で表示されること")
    func remainingTimeText_free3600Seconds_doesNotShowSixtyMinutes() {
        // Given
        let allowanceMock = AllowanceServiceMock()
        allowanceMock.entitlementResult = .free(remaining: 3600)
        let (vm, _, _) = SettingsViewModelTests.setUp(allowanceService: allowanceMock)
        let expected = Duration.seconds(3600).formatted(.units(allowed: [.hours, .minutes], width: .narrow))

        // Then
        #expect(vm.remainingTimeText == expected)
        #expect(!vm.remainingTimeText.contains("60:"), "60分表記のバグが再発していないこと")
    }

    @Test("remainingTimeText: 残高5400秒は時間+分で表示されること")
    func remainingTimeText_free5400Seconds_showsHoursAndMinutes() {
        // Given
        let allowanceMock = AllowanceServiceMock()
        allowanceMock.entitlementResult = .free(remaining: 5400)
        let (vm, _, _) = SettingsViewModelTests.setUp(allowanceService: allowanceMock)
        let expected = Duration.seconds(5400).formatted(.units(allowed: [.hours, .minutes], width: .narrow))

        // Then
        #expect(vm.remainingTimeText == expected)
    }

    @Test("remainingTimeText: 枯渇時は0表示になること")
    func remainingTimeText_exhausted_showsZero() {
        // Given
        let allowanceMock = AllowanceServiceMock()
        allowanceMock.entitlementResult = .exhausted
        let (vm, _, _) = SettingsViewModelTests.setUp(allowanceService: allowanceMock)
        let expected = Duration.seconds(0).formatted(.units(allowed: [.hours, .minutes], width: .narrow))

        // Then
        #expect(vm.remainingTimeText == expected)
    }

    @Test("remainingTimeText: allowanceServiceがnilなら空文字になること")
    func remainingTimeText_noAllowanceService_isEmpty() {
        // Given
        let (vm, _, _) = SettingsViewModelTests.setUp()

        // Then
        #expect(vm.remainingTimeText.isEmpty)
    }
}
