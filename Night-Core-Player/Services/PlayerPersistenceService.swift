import Foundation
import MusicKit

// MARK: - Protocol

/// プレーヤー状態の永続化（save / restore / catalog fetch）を担当する（横断: Persistence）
@MainActor
protocol PlayerPersistenceService: Sendable {
    /// キュー状態を保存する
    func saveQueueState(
        queueIDs: [String],
        currentIndex: Int,
        playbackRate: Double,
        shuffleModeRaw: Int,
        repeatModeRaw: Int
    ) throws
    /// 永続化された状態を読み込む
    func loadState() throws -> (
        queueIDs: [String],
        currentIndex: Int,
        playbackRate: Double,
        shuffleModeRaw: Int,
        repeatModeRaw: Int
    )
    /// 楽曲 ID 配列から MusicKit カタログの Song を取得する（最大100件）
    func fetchCatalogSongs(_ ids: [String]) async throws -> [Song]
    /// 再生履歴の ID 配列を読み込む
    func loadHistoryIDs() throws -> [String]
}

// MARK: - Impl

@MainActor
final class PlayerPersistenceServiceImpl: PlayerPersistenceService {
    private let playerStateRepo: PlayerStateRepository
    private let historyRepo: HistoryRepository

    init(playerStateRepo: PlayerStateRepository, historyRepo: HistoryRepository) {
        self.playerStateRepo = playerStateRepo
        self.historyRepo = historyRepo
    }

    func saveQueueState(
        queueIDs: [String],
        currentIndex: Int,
        playbackRate: Double,
        shuffleModeRaw: Int,
        repeatModeRaw: Int
    ) throws {
        try playerStateRepo.save(
            queueIDs: queueIDs,
            currentIndex: currentIndex,
            playbackRate: playbackRate,
            shuffleModeRaw: shuffleModeRaw,
            repeatModeRaw: repeatModeRaw
        )
    }

    func loadState() throws -> (
        queueIDs: [String],
        currentIndex: Int,
        playbackRate: Double,
        shuffleModeRaw: Int,
        repeatModeRaw: Int
    ) {
        try playerStateRepo.load()
    }

    func fetchCatalogSongs(_ ids: [String]) async throws -> [Song] {
        let itemIDs = ids.map { MusicItemID($0) }
        let batchIDs = Array(itemIDs.prefix(100))
        guard !batchIDs.isEmpty else { return [] }

        let req = MusicCatalogResourceRequest<Song>(
            matching: \.id,
            memberOf: batchIDs
        )
        let response = try await req.response()
        return Array(response.items)
    }

    func loadHistoryIDs() throws -> [String] {
        try historyRepo.loadAll()
    }
}
