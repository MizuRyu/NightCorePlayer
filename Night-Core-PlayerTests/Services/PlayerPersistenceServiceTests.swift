import Testing
import SwiftData
import MediaPlayer

@testable import Night_Core_Player

@Suite(.serialized)
@MainActor
struct PlayerPersistenceServiceTests {

    // MARK: - Helpers

    private static func makeService() -> (
        service: PlayerPersistenceServiceImpl,
        playerStateRepo: PlayerStateRepository,
        historyRepo: HistoryRepository
    ) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: PlayerStateEntity.self,
            HistoryEntity.self,
            configurations: configuration
        )
        let context = container.mainContext
        let playerStateRepo = PlayerStateRepository(context: context)
        let historyRepo = HistoryRepository(context: context)
        let service = PlayerPersistenceServiceImpl(
            playerStateRepo: playerStateRepo,
            historyRepo: historyRepo
        )
        return (service, playerStateRepo, historyRepo)
    }

    // MARK: - Tests

    @Test("save→load: 保存した状態がそのまま読み込めること")
    func testSaveAndLoadRoundTrip() throws {
        let (service, _, _) = PlayerPersistenceServiceTests.makeService()
        let queueIDs = ["id-1", "id-2", "id-3"]
        let currentIndex = 1
        let playbackRate = 1.5
        let shuffleModeRaw = MPMusicShuffleMode.songs.rawValue
        let repeatModeRaw = MPMusicRepeatMode.all.rawValue

        try service.saveQueueState(
            queueIDs: queueIDs,
            currentIndex: currentIndex,
            playbackRate: playbackRate,
            shuffleModeRaw: shuffleModeRaw,
            repeatModeRaw: repeatModeRaw,
            isAutoPlayEnabled: true
        )
        let loaded = try service.loadState()

        #expect(loaded.queueIDs == queueIDs, "queueIDsが一致")
        #expect(loaded.currentIndex == currentIndex, "currentIndexが一致")
        #expect(loaded.playbackRate == playbackRate, "playbackRateが一致")
        #expect(loaded.shuffleModeRaw == shuffleModeRaw, "shuffleModeRawが一致")
        #expect(loaded.repeatModeRaw == repeatModeRaw, "repeatModeRawが一致")
        #expect(loaded.isAutoPlayEnabled == true, "isAutoPlayEnabledが一致")
    }

    @Test("loadState: 空のDBからデフォルト値が返ること")
    func testLoadEmptyDB() throws {
        let (service, _, _) = PlayerPersistenceServiceTests.makeService()

        let loaded = try service.loadState()

        #expect(loaded.queueIDs.isEmpty, "queueIDsは空")
        #expect(loaded.currentIndex == 0, "currentIndexは0")
        #expect(
            loaded.playbackRate == Constants.MusicPlayer.defaultPlaybackRate,
            "playbackRateはデフォルト値"
        )
        #expect(
            loaded.shuffleModeRaw == MPMusicShuffleMode.off.rawValue,
            "shuffleModeRawはoff"
        )
        #expect(
            loaded.repeatModeRaw == MPMusicRepeatMode.none.rawValue,
            "repeatModeRawはnone"
        )
        #expect(
            loaded.isAutoPlayEnabled == false,
            "isAutoPlayEnabledはfalse"
        )
    }

    @Test("loadHistoryIDs: 空の履歴から空配列が返ること")
    func testLoadHistoryIDsEmpty() throws {
        let (service, _, _) = PlayerPersistenceServiceTests.makeService()

        let ids = try service.loadHistoryIDs()

        #expect(ids.isEmpty, "空の履歴から空配列が返る")
    }

    @Test("loadHistoryIDs: 追加後にIDが取得できること")
    func testLoadHistoryIDsAfterAppend() throws {
        let (service, _, historyRepo) = PlayerPersistenceServiceTests.makeService()

        try historyRepo.append(songID: "song-A")
        try historyRepo.append(songID: "song-B")
        let ids = try service.loadHistoryIDs()

        #expect(ids.count == 2, "2件の履歴がある")
        #expect(ids[0] == "song-B", "1件目はsong-B（新しい順）")
        #expect(ids[1] == "song-A", "2件目はsong-A（新しい順）")
    }
}
