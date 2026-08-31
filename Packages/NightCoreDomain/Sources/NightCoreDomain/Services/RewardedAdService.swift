import Foundation

/// リワード広告の再生境界。広告SDKの実装はアプリ側(Infrastructure)に残す
@MainActor
public protocol RewardedAdService: Sendable {
    func preload() async
    func present() async throws -> Bool
}
