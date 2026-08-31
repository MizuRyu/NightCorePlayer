import NightCoreDomain
import NightCoreDomainTestSupport
import Testing

/// 再生履歴の重複排除・上限トリムの検証。songID 抽出を注入するため Item == String で固定する
@Suite("PlayHistoryManager Tests", .serialized)
@MainActor
struct PlayHistoryManagerTests {
    // MARK: - Helpers

    private static func makeManager() -> (
        manager: PlayHistoryManagerImpl<String>,
        repo: InMemoryHistoryRepository
    ) {
        let repo = InMemoryHistoryRepository()
        let manager = PlayHistoryManagerImpl<String>(historyRepo: repo, songID: { $0 })
        return (manager, repo)
    }

    // MARK: - Tests

    @Test("append: 曲を追加すると履歴に含まれること")
    func append_newSong_addsToHistory() throws {
        let (manager, _) = PlayHistoryManagerTests.makeManager()

        try manager.append("song-1")

        #expect(manager.history == ["song-1"], "追加した曲が履歴に含まれる")
    }

    @Test("append: リポジトリにも songID が永続化されること")
    func append_newSong_persistsSongID() throws {
        let (manager, repo) = PlayHistoryManagerTests.makeManager()

        try manager.append("song-1")
        try manager.append("song-2")

        #expect(try repo.loadAll() == ["song-2", "song-1"], "リポジトリは新しい順で保持する")
    }

    @Test("append: 同じ曲を連続で追加しても重複しないこと")
    func append_duplicateSong_skipped() throws {
        let (manager, repo) = PlayHistoryManagerTests.makeManager()

        try manager.append("song-dup")
        try manager.append("song-dup")

        #expect(manager.history == ["song-dup"], "重複は追加されない")
        #expect(try repo.loadAll() == ["song-dup"], "リポジトリにも重複を書かない")
    }

    @Test("append: 連続でなければ同じ曲を再度追加できること")
    func append_sameSongAfterAnother_added() throws {
        let (manager, _) = PlayHistoryManagerTests.makeManager()

        try manager.append("song-a")
        try manager.append("song-b")
        try manager.append("song-a")

        #expect(manager.history == ["song-a", "song-b", "song-a"], "直前と異なれば追加される")
    }

    @Test("append: maxHistoryCountを超えると古い曲がトリミングされること")
    func append_exceedsMax_trimsOldest() throws {
        let (manager, _) = PlayHistoryManagerTests.makeManager()
        let maxCount = Constants.History.maxHistoryCount

        for i in 0 ..< (maxCount + 5) {
            try manager.append("song-\(i)")
        }

        #expect(
            manager.history.count == maxCount,
            "履歴がmaxHistoryCount(\(maxCount))にトリミングされる"
        )
        #expect(manager.history.first == "song-5", "古い曲が削除されている")
        #expect(manager.history.last == "song-\(maxCount + 4)", "最新の曲は残る")
    }

    @Test("clearHistory: 履歴がクリアされること")
    func clearHistory_withEntries_clearsAll() throws {
        let (manager, repo) = PlayHistoryManagerTests.makeManager()
        try manager.append("song-a")
        try manager.append("song-b")
        #expect(manager.history.count == 2, "クリア前に2件ある")

        try manager.clearHistory()

        #expect(manager.history.isEmpty, "履歴が空になる")
        #expect(try repo.loadAll().isEmpty, "リポジトリも空になる")
    }

    @Test("restoreHistory: 渡した配列がそのまま履歴に設定されること")
    func restoreHistory_songs_setsHistory() {
        let (manager, _) = PlayHistoryManagerTests.makeManager()

        manager.restoreHistory(["r-1", "r-2", "r-3"])

        #expect(manager.history == ["r-1", "r-2", "r-3"], "3件が順序どおり復元される")
    }
}
