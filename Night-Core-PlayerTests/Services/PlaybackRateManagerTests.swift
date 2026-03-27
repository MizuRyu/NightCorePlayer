import Testing
import SwiftData
import MediaPlayer

@testable import Night_Core_Player

@Suite(.serialized)
@MainActor
struct PlaybackRateManagerTests {

    // MARK: - Helpers

    private static func makeRepo() -> PlayerStateRepository {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: PlayerStateEntity.self,
            HistoryEntity.self,
            configurations: configuration
        )
        let context = container.mainContext
        return PlayerStateRepository(context: context)
    }

    // MARK: - Tests

    @Test("初期化: 空のリポジトリからデフォルト再生速度が返ること")
    func testInitialDefaultRate() throws {
        let repo = PlaybackRateManagerTests.makeRepo()
        let manager = PlaybackRateManagerImpl(repo: repo)

        #expect(
            manager.defaultRate == Constants.MusicPlayer.defaultPlaybackRate,
            "空のリポジトリから初期化した場合、デフォルト再生速度であること"
        )
    }

    @Test("setDefaultRate: 1.5を設定するとリポジトリとメモリに反映されること")
    func testSetDefaultRate() throws {
        let repo = PlaybackRateManagerTests.makeRepo()
        let manager = PlaybackRateManagerImpl(repo: repo)

        try manager.setDefaultRate(1.5)

        #expect(manager.defaultRate == 1.5, "メモリ上のdefaultRateが1.5")
        let loaded = try repo.load()
        #expect(loaded.playbackRate == 1.5, "リポジトリのplaybackRateが1.5")
    }

    @Test("setDefaultRate: 最大値を超える速度はクランプされること")
    func testSetDefaultRateClampMax() throws {
        let repo = PlaybackRateManagerTests.makeRepo()
        let manager = PlaybackRateManagerImpl(repo: repo)

        try manager.setDefaultRate(999.0)

        #expect(
            manager.defaultRate == Constants.MusicPlayer.maxPlaybackRate,
            "最大値にクランプされること"
        )
    }

    @Test("setDefaultRate: 最小値を下回る速度はクランプされること")
    func testSetDefaultRateClampMin() throws {
        let repo = PlaybackRateManagerTests.makeRepo()
        let manager = PlaybackRateManagerImpl(repo: repo)

        try manager.setDefaultRate(0.01)

        #expect(
            manager.defaultRate == Constants.MusicPlayer.minPlaybackRate,
            "最小値にクランプされること"
        )
    }

    @Test("永続化: 別インスタンスで設定した速度が復元されること")
    func testPersistenceAcrossInstances() throws {
        let repo = PlaybackRateManagerTests.makeRepo()
        let manager1 = PlaybackRateManagerImpl(repo: repo)
        try manager1.setDefaultRate(2.0)

        let manager2 = PlaybackRateManagerImpl(repo: repo)

        #expect(manager2.defaultRate == 2.0, "別インスタンスで速度が復元されること")
    }
}
