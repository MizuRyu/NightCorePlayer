import SwiftData
@testable import Night_Core_Player

/// テスト用の in-memory ストア。実DB (AppDataStore.shared) を汚さないためのもの (#87)。
/// プロセス内で共有される点は AppDataStore.shared と同じで、
/// 「Repository を作り直しても状態が維持される」系のテスト前提を保つ
@MainActor
enum TestDataStore {
    static let container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(
                for: PlayerStateEntity.self,
                HistoryEntity.self,
                AllowanceEntity.self,
                configurations: config
            )
        } catch {
            fatalError("テスト用 in-memory ModelContainer の初期化に失敗しました: \(error)")
        }
    }()
}
