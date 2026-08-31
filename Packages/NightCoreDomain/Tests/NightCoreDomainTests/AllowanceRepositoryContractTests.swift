import Testing
import Foundation
import NightCoreDomain
import NightCoreDomainTestSupport

/// InMemoryAllowanceRepository が AllowanceRepositoryPort の契約を満たすことの検証。
/// 同じ契約はアプリ側の AllowanceRepositoryTests (SwiftData実装) からも呼ばれる
@Suite("AllowanceRepositoryContract Tests (fake)")
@MainActor
struct AllowanceRepositoryContractTests {

    private static let day0 = ISO8601DateFormatter().date(from: "2026-08-01T12:00:00+09:00")!

    @Test
    func loadOrCreate() throws {
        try AllowanceRepositoryContract.verifyLoadOrCreate(
            { InMemoryAllowanceRepository() },
            now: Self.day0
        )
    }

    @Test
    func save() throws {
        // 「Repository を作り直しても復元される」検証のため、make() は同じ fake を返す
        // (in-memory fake は状態をインスタンス自身が持つため)
        let repo = InMemoryAllowanceRepository()
        try AllowanceRepositoryContract.verifySave(
            { repo },
            now: Self.day0
        )
    }

    @Test
    func reset() throws {
        try AllowanceRepositoryContract.verifyReset(
            { InMemoryAllowanceRepository() },
            now: Self.day0
        )
    }
}
