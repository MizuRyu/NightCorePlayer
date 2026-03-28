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
        #expect(rateMock.setDefaultRateArgs.first == minRate, "rateManagerにmin値が渡される")
        #expect(svcMock.rateArgs.first == minRate, "playerServiceにmin値が渡される")
    }
}
