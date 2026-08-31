import Foundation

/// 残高の永続化境界。具体実装はアプリ側(Infrastructure)に残す
public protocol AllowanceRepositoryPort {
    func loadOrCreate(now: Date) throws -> AllowanceSnapshot
    func save(_ snapshot: AllowanceSnapshot) throws
    func reset() throws
}
