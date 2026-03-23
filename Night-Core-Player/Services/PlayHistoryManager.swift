import Foundation
import MusicKit

// MARK: - Protocol

/// 再生履歴の管理を担当する（Playback コンテキスト サブモジュール）
@MainActor
protocol PlayHistoryManaging: Sendable {
    /// 現在の再生履歴
    var history: [Song] { get }
    /// 履歴に曲を追加する（重複チェック + 上限トリミング付き）
    func append(_ song: Song) throws
    /// 履歴をクリアする
    func clearHistory() throws
    /// 履歴を復元する（起動時）
    func restoreHistory(_ songs: [Song])
}

// MARK: - Impl

@MainActor
final class PlayHistoryManagerImpl: PlayHistoryManaging {
    private let historyRepo: HistoryRepository
    private let maxHistoryCount: Int = Constants.History.maxHistoryCount

    private(set) var history: [Song] = []

    init(historyRepo: HistoryRepository) {
        self.historyRepo = historyRepo
    }

    func append(_ song: Song) throws {
        guard history.last?.id.rawValue != song.id.rawValue else { return }
        history.append(song)
        if history.count > maxHistoryCount {
            history.removeFirst(history.count - maxHistoryCount)
        }
        try historyRepo.append(songID: song.id.rawValue)
    }

    func clearHistory() throws {
        history.removeAll()
        try historyRepo.clear()
    }

    func restoreHistory(_ songs: [Song]) {
        history = songs
    }
}
