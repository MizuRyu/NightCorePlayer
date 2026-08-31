import Foundation
import StoreKit
@testable import Night_Core_Player

@MainActor
final class ProStoreServiceMock: ProStoreService {
    var entitledResult = false
    var productResult: Product?
    var purchaseResult: Result<ProPurchaseOutcome, Error> = .success(.cancelled)
    var restoreError: Error?
    /// purchase()を指定ミリ秒だけ遅らせ、isPurchasing中の再入テスト用に使う
    var purchaseDelayMilliseconds: Int = 0

    private(set) var loadProductCallCount = 0
    private(set) var purchaseCallCount = 0
    private(set) var restoreCallCount = 0

    var isProEntitled: Bool {
        entitledResult
    }

    func loadProduct() async -> Product? {
        loadProductCallCount += 1
        return productResult
    }

    func purchase() async throws -> ProPurchaseOutcome {
        purchaseCallCount += 1
        if purchaseDelayMilliseconds > 0 {
            try? await Task.sleep(nanoseconds: UInt64(purchaseDelayMilliseconds) * 1_000_000)
        }
        return try purchaseResult.get()
    }

    func restore() async throws {
        restoreCallCount += 1
        if let restoreError {
            throw restoreError
        }
    }
}
