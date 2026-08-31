import Testing
import NightCoreDomain
import NightCoreDomainTestSupport

/// InMemoryHistoryRepository が HistoryRepositoryPort の契約を満たすことの検証。
/// 同じ契約はアプリ側の HistoryRepositoryTests (SwiftData実装) からも呼ばれる
@Suite("HistoryRepositoryContract Tests (fake)")
struct HistoryRepositoryContractTests {

    @Test
    func appendAndLoadAll() throws {
        try HistoryRepositoryContract.verifyAppendAndLoadAll {
            InMemoryHistoryRepository()
        }
    }

    @Test
    func appendTrimsOverflow() throws {
        try HistoryRepositoryContract.verifyAppendTrimsOverflow {
            InMemoryHistoryRepository()
        }
    }

    @Test
    func clear() throws {
        try HistoryRepositoryContract.verifyClear {
            InMemoryHistoryRepository()
        }
    }
}
