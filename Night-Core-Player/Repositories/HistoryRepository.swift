import Foundation
import SwiftData

final class HistoryRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// 再生ごとにレコード追加
    func append(songID: String) {
        let entry = History(songID: songID)
        context.insert(entry)
        saveContext()
    }

    /// 全履歴を再生日時の新しい順で取得
    func loadAll() -> [String] {
        let desc = FetchDescriptor<History>(sortBy: [.init(\.playedAt)])
        return (try? context.fetch(desc))?.map(\.songID) ?? []
    }


    /// 全履歴クリア
    func clear() {
        let descriptor = FetchDescriptor<History>()
        if let list = try? context.fetch(descriptor) {
            list.forEach(context.delete)
            saveContext()
        }
    }

    private func saveContext() {
        do {
            try context.save()
        } catch {
            print("⚠️ History save error:", error)
        }
    }
}
