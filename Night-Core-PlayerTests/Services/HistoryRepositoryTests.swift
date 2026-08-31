import Testing
import SwiftData
import NightCoreDomain
import NightCoreDomainTestSupport

@testable import Night_Core_Player

/// SwiftData 実装が HistoryRepositoryPort の契約を満たすことを検証する
@Suite("HistoryRepository Tests", .serialized)
@MainActor
struct HistoryRepositoryTests {

    // MARK: - Helpers

    private static func makeRepo() -> HistoryRepository {
        HistoryRepository(context: TestDataStore.container.mainContext)
    }

    private static func resetStore() throws {
        let context = TestDataStore.container.mainContext
        let entities = try context.fetch(FetchDescriptor<HistoryEntity>())
        entities.forEach(context.delete)
        try context.save()
    }

    // MARK: - Tests

    @Test("append→loadAll: 新しい順で返ること")
    func appendAndLoadAll() throws {
        try Self.resetStore()
        try HistoryRepositoryContract.verifyAppendAndLoadAll(Self.makeRepo)
    }

    @Test("append: maxHistoryCountを超えると古い方から切り詰められること")
    func appendTrimsOverflow() throws {
        try Self.resetStore()
        try HistoryRepositoryContract.verifyAppendTrimsOverflow(Self.makeRepo)
    }

    @Test("clear: 全件削除されること")
    func clear() throws {
        try Self.resetStore()
        try HistoryRepositoryContract.verifyClear(Self.makeRepo)
    }
}
