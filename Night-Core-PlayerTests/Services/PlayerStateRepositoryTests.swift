import NightCoreDomain
import NightCoreDomainTestSupport
import SwiftData
import Testing
@testable import Night_Core_Player

/// SwiftData 実装が PlayerStateRepositoryPort の契約を満たすことを検証する
@Suite("PlayerStateRepository Tests", .serialized)
@MainActor
struct PlayerStateRepositoryTests {
    // MARK: - Helpers

    private static func makeRepo() -> PlayerStateRepository {
        PlayerStateRepository(context: TestDataStore.container.mainContext)
    }

    private static func resetStore() throws {
        let context = TestDataStore.container.mainContext
        let entities = try context.fetch(FetchDescriptor<PlayerStateEntity>())
        entities.forEach(context.delete)
        try context.save()
    }

    // MARK: - Tests

    @Test("load: 未保存時はデフォルト値(shuffle=off, repeat=none)が返ること")
    func loadDefaults() throws {
        try Self.resetStore()
        try PlayerStateRepositoryContract.verifyLoadDefaults(Self.makeRepo)
    }

    @Test("save→load: 別インスタンスから読み直しても保存した値が復元されること")
    func saveAndLoad() throws {
        try Self.resetStore()
        try PlayerStateRepositoryContract.verifySaveAndLoad(Self.makeRepo)
    }
}
