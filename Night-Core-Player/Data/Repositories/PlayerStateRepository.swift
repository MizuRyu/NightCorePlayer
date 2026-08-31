import Foundation
import SwiftData
import MediaPlayer
import NightCoreDomain

final class PlayerStateRepository: PlayerStateRepositoryPort {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func save(
        queueIDs: [String],
        currentIndex: Int,
        playbackRate: Double,
        shuffleModeRaw: Int,
        repeatModeRaw: Int,
        isAutoPlayEnabled: Bool
    ) throws {
        let entity = try fetch() ?? PlayerStateEntity()
        entity.queueIDs      = queueIDs
        entity.currentIndex  = currentIndex
        entity.playbackRate  = playbackRate
        entity.shuffleModeRaw = shuffleModeRaw
        entity.repeatModeRaw  = repeatModeRaw
        entity.isAutoPlayEnabled = isAutoPlayEnabled

        if try fetch() == nil {
            context.insert(entity)
        }
        try context.save()
    }

    // swiftlint:disable:next large_tuple
    func load() throws -> (
        queueIDs: [String],
        currentIndex: Int,
        playbackRate: Double,
        shuffleModeRaw: Int,
        repeatModeRaw: Int,
        isAutoPlayEnabled: Bool
    ) {
        guard let e = try fetch() else {
            return (
                [], 0,
                Constants.MusicPlayer.defaultPlaybackRate,
                MPMusicShuffleMode.off.rawValue,
                MPMusicRepeatMode.none.rawValue,
                false
            )
        }
        return (e.queueIDs, e.currentIndex, e.playbackRate, e.shuffleModeRaw, e.repeatModeRaw, e.isAutoPlayEnabled)
    }

    private func fetch() throws -> PlayerStateEntity? {
        let descriptor = FetchDescriptor<PlayerStateEntity>(
            predicate: #Predicate { $0.id == "default" }
        )
        return try context.fetch(descriptor).first
    }
}
