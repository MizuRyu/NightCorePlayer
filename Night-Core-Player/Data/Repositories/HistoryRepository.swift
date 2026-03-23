import Foundation
import SwiftData

final class HistoryRepository {
    private let context: ModelContext
    private let maxHistoryCount = Constants.History.maxHistoryCount

    init(context: ModelContext) {
        self.context = context
    }

    /// 再生ごとにレコード追加
    func append(songID: String) throws {
        let entry = HistoryEntity(songID: songID)
        context.insert(entry)

        try trimOverflowIfNeeded()
        try context.save()
    }

    /// 再生履歴読み込み（新しい順）
    func loadAll() throws -> [String] {
        var desc = FetchDescriptor<HistoryEntity>(
            sortBy: [.init(\.playedAt, order: .reverse)])
        desc.fetchLimit = maxHistoryCount
        return try context.fetch(desc).map(\.songID)
    }

    /// 全履歴クリア
    func clear() throws {
        let descriptor = FetchDescriptor<HistoryEntity>()
        let list = try context.fetch(descriptor)
        list.forEach(context.delete)
        try context.save()
    }

    // 履歴が最大保持数を超えた場合、古い順に削除
    private func trimOverflowIfNeeded() throws {
        var desc = FetchDescriptor<HistoryEntity>(
            sortBy: [.init(\.playedAt, order: .forward)]
        )
        desc.fetchLimit = max(0, maxHistoryCount + 1)

        let list = try context.fetch(desc)
        guard list.count > maxHistoryCount else { return }

        let overflow = list.count - maxHistoryCount
        list.prefix(overflow).forEach(context.delete)
    }
}
