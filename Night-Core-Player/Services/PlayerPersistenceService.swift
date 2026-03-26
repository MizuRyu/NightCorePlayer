import Foundation
import MusicKit

// MARK: - Protocol

@MainActor
protocol PlayerPersistenceService: Sendable {
    func saveQueueState(
        queueIDs: [String],
        currentIndex: Int,
        playbackRate: Double,
        shuffleModeRaw: Int,
        repeatModeRaw: Int,
        isAutoPlayEnabled: Bool
    ) throws
    func loadState() throws -> (
        queueIDs: [String],
        currentIndex: Int,
        playbackRate: Double,
        shuffleModeRaw: Int,
        repeatModeRaw: Int,
        isAutoPlayEnabled: Bool
    )
    func fetchCatalogSongs(_ ids: [String]) async throws -> [Song]
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
        repeatModeRaw: Int,
        isAutoPlayEnabled: Bool
    ) throws {
        try playerStateRepo.save(
            queueIDs: queueIDs,
            currentIndex: currentIndex,
            playbackRate: playbackRate,
            shuffleModeRaw: shuffleModeRaw,
            repeatModeRaw: repeatModeRaw,
            isAutoPlayEnabled: isAutoPlayEnabled
        )
    }

    func loadState() throws -> (
        queueIDs: [String],
        currentIndex: Int,
        playbackRate: Double,
        shuffleModeRaw: Int,
        repeatModeRaw: Int,
        isAutoPlayEnabled: Bool
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
