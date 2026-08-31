import Testing
import NightCoreDomain
import NightCoreDomainTestSupport

/// InMemoryPlayerStateRepository が PlayerStateRepositoryPort の契約を満たすことの検証。
/// 同じ契約はアプリ側の PlayerStateRepositoryTests (SwiftData実装) からも呼ばれる
@Suite("PlayerStateRepositoryContract Tests (fake)")
@MainActor
struct PlayerStateRepositoryContractTests {

    @Test
    func loadDefaults() throws {
        try PlayerStateRepositoryContract.verifyLoadDefaults {
            InMemoryPlayerStateRepository()
        }
    }

    @Test
    func saveAndLoad() throws {
        // 「別インスタンスから読み直せる」検証のため、make() は同じ fake を返す
        // (in-memory fake は状態をインスタンス自身が持つため)
        let repo = InMemoryPlayerStateRepository()
        try PlayerStateRepositoryContract.verifySaveAndLoad { repo }
    }
}
