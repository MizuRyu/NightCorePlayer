import Foundation
import SwiftData

struct AppDataStore {
    static let shared = AppDataStore()
    let container: ModelContainer
    
    private init() {
        do {
            container = try ModelContainer(
                for: PlayerStateEntity.self,
                HistoryEntity.self
            )
        } catch {
            // スキーマ変更で旧 DB と互換性がない場合、ストアを削除して再作成
            Self.deleteStoreFiles()
            do {
                container = try ModelContainer(
                    for: PlayerStateEntity.self,
                    HistoryEntity.self
                )
            } catch {
                fatalError("SwiftData ModelContainer の初期化に失敗しました: \(error)")
            }
        }
    }

    private static func deleteStoreFiles() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        let storeName = "default.store"
        let extensions = ["", "-shm", "-wal"]
        for ext in extensions {
            let url = appSupport.appendingPathComponent(storeName + ext)
            try? FileManager.default.removeItem(at: url)
        }
    }
}

