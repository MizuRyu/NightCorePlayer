import Foundation
import Testing
import NightCoreDomain

/// HistoryRepositoryPort の契約検証。fake(InMemoryHistoryRepository)と
/// アプリ側の永続化実装(HistoryRepository)の両方から同じアサーションを実行するために使う
public enum HistoryRepositoryContract {

    public static func verifyAppendAndLoadAll(
        _ make: () throws -> any HistoryRepositoryPort
    ) throws {
        let repo = try make()

        #expect(try repo.loadAll().isEmpty)

        try repo.append(songID: "song-A")
        try repo.append(songID: "song-B")
        try repo.append(songID: "song-C")

        // 新しい順で返る
        #expect(try repo.loadAll() == ["song-C", "song-B", "song-A"])
    }

    public static func verifyAppendTrimsOverflow(
        _ make: () throws -> any HistoryRepositoryPort
    ) throws {
        let repo = try make()
        let maxCount = Constants.History.maxHistoryCount

        for i in 0..<(maxCount + 5) {
            try repo.append(songID: "song-\(i)")
        }

        let ids = try repo.loadAll()
        #expect(ids.count == maxCount)
        #expect(ids.first == "song-\(maxCount + 4)")
        #expect(ids.last == "song-5")
    }

    public static func verifyClear(
        _ make: () throws -> any HistoryRepositoryPort
    ) throws {
        let repo = try make()
        try repo.append(songID: "song-A")
        try repo.append(songID: "song-B")
        #expect(try repo.loadAll().count == 2)

        try repo.clear()

        #expect(try repo.loadAll().isEmpty)
    }
}
