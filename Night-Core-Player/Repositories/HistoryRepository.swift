import Foundation
import SwiftData

final class HistoryRepository {
    private let context: ModelContext
    private let maxHistoryCount = Constants.History.maxHistoryCount

    init(context: ModelContext) {
        self.context = context
    }

    /// 再生ごとにレコード追加
    func append(songID: String) {
        let entry = History(songID: songID)
        context.insert(entry)

        trimOverflowIfNeeded()
        saveContext()
    }

    /// 再生履歴読み込み
    func loadAll() -> [String] {
        var desc = FetchDescriptor<History>(
            sortBy: [.init(\.playedAt, order: .forward)])
        desc.fetchLimit = maxHistoryCount
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

    // 履歴が最大保持数を超えた場合、古い順に削除
    private func trimOverflowIfNeeded() {
        var desc = FetchDescriptor<History>(
            sortBy: [.init(\.playedAt, order: .forward)]
        )
        desc.fetchLimit = max(0, maxHistoryCount + 1)

        guard let list = try? context.fetch(desc),
              list.count > maxHistoryCount else { return }

        let overflow = list.count - maxHistoryCount
        list.prefix(overflow).forEach(context.delete)
    }
}
