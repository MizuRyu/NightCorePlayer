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
        // 「別インスタンスから読み直せる」検証のため、make() は同じ store を
        // 共有する別インスタンスを毎回返す
        let store = InMemoryPlayerStateStore()
        try PlayerStateRepositoryContract.verifySaveAndLoad {
            InMemoryPlayerStateRepository(store: store)
        }
    }
}
