import Testing
import Foundation
import NightCoreDomain
import NightCoreDomainTestSupport

@testable import Night_Core_Player

/// 残高ロジックのテストは NightCoreDomain 側 (fake ベース) にある。
/// ここは SwiftData 実装が AllowanceRepositoryPort の契約を満たすことを検証する
@Suite("AllowanceRepository Tests", .serialized)
@MainActor
struct AllowanceRepositoryTests {

    // MARK: - Helpers

    private static let day0 = ISO8601DateFormatter().date(from: "2026-08-01T12:00:00+09:00")!

    private static func makeRepo() -> AllowanceRepository {
        AllowanceRepository(context: TestDataStore.container.mainContext)
    }

    private static func resetStore() throws {
        try makeRepo().reset()
    }

    // MARK: - Tests

    @Test("loadOrCreate: 初回は既定の残高で作成し、2回目以降はnowを無視して初回の値を返すこと")
    func loadOrCreate() throws {
        try Self.resetStore()
        try AllowanceRepositoryContract.verifyLoadOrCreate(Self.makeRepo, now: Self.day0)
    }

    @Test("save: エンティティ未作成でも保存でき、Repositoryを作り直しても復元されること")
    func save() throws {
        try Self.resetStore()
        try AllowanceRepositoryContract.verifySave(Self.makeRepo, now: Self.day0)
    }

    @Test("reset: 記録が消え、次のloadOrCreateが初回扱いになること")
    func reset() throws {
        try Self.resetStore()
        try AllowanceRepositoryContract.verifyReset(Self.makeRepo, now: Self.day0)
    }
}
