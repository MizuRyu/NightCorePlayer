import Foundation
import StoreKit
import Observation
import os

// MARK: - Outcome

/// purchase()の結果種別。キャンセルと承認待ちをBoolでは区別できないため分けている
enum ProPurchaseOutcome {
    case purchased
    case cancelled
    case pending
    /// 商品をStoreKitから取得できず購入を開始できなかった。ユーザー操作によるcancelledと区別する
    case unavailable
}

// MARK: - Protocol

@MainActor
protocol ProStoreService: Sendable {
    var isProEntitled: Bool { get }
    func loadProduct() async -> Product?
    func purchase() async throws -> ProPurchaseOutcome
    func restore() async throws
}

// MARK: - Impl

@Observable
@MainActor
final class ProStoreServiceImpl: ProStoreService {
    private let logger = Logger(subsystem: Constants.Logging.subsystem, category: "ProStore")

    static let productID = "MizuRyu.Night-Core-Player.pro"

    private(set) var isProEntitled = false

    // deinit(nonisolated)からcancelするため隔離を外す。書き込みはinitのみ
    private nonisolated(unsafe) var updatesTask: Task<Void, Never>?

    /// 取得済みの商品。purchase()のたびの再取得を避ける
    private var cachedProduct: Product?

    init() {
        updatesTask = Task { [weak self] in
            await self?.observeTransactionUpdates()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProduct() async -> Product? {
        do {
            let products = try await Product.products(for: [Self.productID])
            cachedProduct = products.first
            return cachedProduct
        } catch {
            logger.error("Pro product load failed: \(error.localizedDescription)")
            return nil
        }
    }

    func purchase() async throws -> ProPurchaseOutcome {
        let product: Product
        if let cachedProduct {
            product = cachedProduct
        } else if let loaded = await loadProduct() {
            product = loaded
        } else {
            logger.error("Pro product not found: \(Self.productID)")
            return .unavailable
        }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            // 検証失敗時はfinishせずエラーとして返す（不正トランザクションを完了扱いにしない）
            let transaction = try Self.checkVerified(verification)
            await refreshEntitlement()
            await transaction.finish()
            logger.info("Pro purchased (transaction id: \(transaction.id))")
            return .purchased
        case .userCancelled:
            return .cancelled
        case .pending:
            logger.info("Pro purchase pending approval")
            return .pending
        @unknown default:
            logger.error("Unknown purchase result")
            return .cancelled
        }
    }

    func restore() async throws {
        try await AppStore.sync()
        await refreshEntitlement()
        logger.info("Pro entitlements refreshed after restore (entitled: \(self.isProEntitled))")
    }

    // MARK: - Private

    private func observeTransactionUpdates() async {
        // 起動直後の権限状態を先に同期してから更新監視に入る
        await refreshEntitlement()
        for await update in Transaction.updates {
            do {
                let transaction = try Self.checkVerified(update)
                await refreshEntitlement()
                await transaction.finish()
                logger.info("Transaction update processed (transaction id: \(transaction.id))")
            } catch {
                // 検証失敗トランザクションは finish しない方針のため Transaction.updates に再配信され続ける
                logger.fault("Transaction update verification failed: \(error.localizedDescription)")
            }
        }
    }

    private func refreshEntitlement() async {
        var entitled = false
        for await entitlement in Transaction.currentEntitlements {
            guard let transaction = try? Self.checkVerified(entitlement) else { continue }
            if transaction.productID == Self.productID, transaction.revocationDate == nil {
                entitled = true
                break
            }
        }
        isProEntitled = entitled
    }

    private nonisolated static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}
