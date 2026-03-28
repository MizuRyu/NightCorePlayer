import Testing
import SwiftData
import MusicKit

@testable import Night_Core_Player

@Suite(.serialized)
@MainActor
struct PlayHistoryManagerTests {

    // MARK: - Helpers

    private static func makeManager() -> (
        manager: PlayHistoryManagerImpl,
        historyRepo: HistoryRepository
    ) {
        let context = AppDataStore.shared.container.mainContext
        let historyRepo = HistoryRepository(context: context)
        let manager = PlayHistoryManagerImpl(historyRepo: historyRepo)
        return (manager, historyRepo)
    }

    /// History をクリアする
    private static func cleanHistory() throws {
        let context = AppDataStore.shared.container.mainContext
        let histories = try context.fetch(FetchDescriptor<HistoryEntity>())
        histories.forEach(context.delete)
        try context.save()
    }

    // MARK: - Tests

    @Test("append: 曲を追加すると履歴に含まれること")
    func testAppendAddsToHistory() throws {
        try PlayHistoryManagerTests.cleanHistory()
        let (manager, _) = PlayHistoryManagerTests.makeManager()
        let song = makeDummySong(id: "song-1", title: "Test Song")

        try manager.append(song)

        #expect(manager.history.count == 1, "履歴に1件追加される")
        #expect(
            manager.history.first?.id.rawValue == "song-1",
            "追加した曲が履歴に含まれる"
        )
    }

    @Test("append: 同じ曲を連続で追加しても重複しないこと")
    func testAppendSkipsDuplicate() throws {
        try PlayHistoryManagerTests.cleanHistory()
        let (manager, _) = PlayHistoryManagerTests.makeManager()
        let song = makeDummySong(id: "song-dup")

        try manager.append(song)
        try manager.append(song)

        #expect(manager.history.count == 1, "重複は追加されない")
    }

    @Test("append: maxHistoryCountを超えると古い曲がトリミングされること")
    func testAppendTrimsOverflow() throws {
        try PlayHistoryManagerTests.cleanHistory()
        let (manager, _) = PlayHistoryManagerTests.makeManager()
        let maxCount = Constants.History.maxHistoryCount

        for i in 0..<(maxCount + 5) {
            let song = makeDummySong(id: "song-\(i)")
            try manager.append(song)
        }

        #expect(
            manager.history.count == maxCount,
            "履歴がmaxHistoryCount(\(maxCount))にトリミングされる"
        )
        #expect(
            manager.history.first?.id.rawValue == "song-5",
            "古い曲が削除されている"
        )
    }

    @Test("clearHistory: 履歴がクリアされること")
    func testClearHistory() throws {
        try PlayHistoryManagerTests.cleanHistory()
        let (manager, _) = PlayHistoryManagerTests.makeManager()
        try manager.append(makeDummySong(id: "song-a"))
        try manager.append(makeDummySong(id: "song-b"))
        #expect(manager.history.count == 2, "クリア前に2件ある")

        try manager.clearHistory()

        #expect(manager.history.isEmpty, "履歴が空になる")
    }

    @Test("restoreHistory: 渡した配列がそのまま履歴に設定されること")
    func testRestoreHistory() throws {
        try PlayHistoryManagerTests.cleanHistory()
        let (manager, _) = PlayHistoryManagerTests.makeManager()
        let songs = [
            makeDummySong(id: "r-1", title: "Restored 1"),
            makeDummySong(id: "r-2", title: "Restored 2"),
            makeDummySong(id: "r-3", title: "Restored 3"),
        ]

        manager.restoreHistory(songs)

        #expect(manager.history.count == 3, "3件復元される")
        #expect(manager.history[0].id.rawValue == "r-1", "1件目が正しい")
        #expect(manager.history[1].id.rawValue == "r-2", "2件目が正しい")
        #expect(manager.history[2].id.rawValue == "r-3", "3件目が正しい")
    }
}
