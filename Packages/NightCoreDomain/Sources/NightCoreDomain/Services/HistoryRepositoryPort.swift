import Foundation

/// 再生履歴の永続化境界。具体実装はアプリ側(Infrastructure)に残す
public protocol HistoryRepositoryPort {
    func append(songID: String) throws
    func loadAll() throws -> [String]
    func clear() throws
}
