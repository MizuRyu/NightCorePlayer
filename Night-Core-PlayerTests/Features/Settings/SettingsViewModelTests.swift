import Testing

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

// MARK: - Tests

@Suite(.serialized)
@MainActor
struct SettingsViewModelTests {

    // MARK: - Helpers

    private static func setUp() -> (
        vm: SettingsViewModel,
        rateMock: PlaybackRateManagerMock,
        svcMock: MusicPlayerServiceMock
    ) {
        let rateMock = PlaybackRateManagerMock()
        let svcMock = MusicPlayerServiceMock()
        let vm = SettingsViewModel(
            rateManager: rateMock,
            playerService: svcMock
        )
        return (vm, rateMock, svcMock)
    }

    // MARK: - Tests

    @Test("初期化: rateManagerのdefaultRateがViewModelに反映されること")
    func testInitialRate() {
        // Given: デフォルト速度のrateManager
        let (vm, rateMock, _) = SettingsViewModelTests.setUp()

        // Then: ViewModelのdefaultRateがrateManagerの値と一致する
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
    func testUpdateDefaultRate() async throws {
        // Given
        let (vm, rateMock, svcMock) = SettingsViewModelTests.setUp()

        // When
        vm.updateDefaultRate(to: 1.8)
        try await Task.sleep(nanoseconds: 200_000_000)

        // Then: rateManagerに渡された値
        #expect(rateMock.setDefaultRateArgs.count == 1, "setDefaultRateが1回呼ばれる")
        #expect(rateMock.setDefaultRateArgs.first == 1.8, "値が1.8で渡される")
        // Then: playerServiceにも反映される
        #expect(svcMock.rateArgs.count == 1, "setSessionRateが1回呼ばれる")
        #expect(svcMock.rateArgs.first == 1.8, "sessionRateも1.8")
        // Then: ViewModelのdefaultRateも更新される
        #expect(vm.defaultRate == 1.8, "ViewModelのdefaultRateが1.8")
    }

    @Test("updateDefaultRate: 範囲外の値がクランプされること")
    func testUpdateDefaultRateClamps() async throws {
        // Given
        let (vm, rateMock, svcMock) = SettingsViewModelTests.setUp()

        // When: 最大値を超える値を設定
        vm.updateDefaultRate(to: 100.0)
        try await Task.sleep(nanoseconds: 200_000_000)

        // Then: maxPlaybackRateにクランプされる
        let maxRate = Constants.MusicPlayer.maxPlaybackRate
        #expect(vm.defaultRate == maxRate, "ViewModelのdefaultRateがmaxにクランプ")
        #expect(
            rateMock.setDefaultRateArgs.first == maxRate,
            "rateManagerにクランプ後の値が渡される"
        )
        #expect(
            svcMock.rateArgs.first == maxRate,
            "playerServiceにクランプ後の値が渡される"
        )

        // When: 最小値を下回る値を設定
        vm.updateDefaultRate(to: 0.01)
        try await Task.sleep(nanoseconds: 200_000_000)

        // Then: minPlaybackRateにクランプされる
        let minRate = Constants.MusicPlayer.minPlaybackRate
        #expect(vm.defaultRate == minRate, "ViewModelのdefaultRateがminにクランプ")
        #expect(
            rateMock.setDefaultRateArgs.last == minRate,
            "rateManagerにmin値が渡される"
        )
        #expect(
            svcMock.rateArgs.last == minRate,
            "playerServiceにmin値が渡される"
        )
    }
}
