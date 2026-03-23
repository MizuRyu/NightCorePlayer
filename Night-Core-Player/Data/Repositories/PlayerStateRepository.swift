import Foundation
import SwiftData
import MediaPlayer

final class PlayerStateRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// 保存 or 更新
    func save(
        queueIDs: [String],
        currentIndex: Int,
        playbackRate: Double,
        shuffleModeRaw: Int,
        repeatModeRaw: Int
    ) throws {
        let entity = try fetch() ?? PlayerStateEntity()
        entity.queueIDs      = queueIDs
        entity.currentIndex  = currentIndex
        entity.playbackRate  = playbackRate
        entity.shuffleModeRaw = shuffleModeRaw
        entity.repeatModeRaw  = repeatModeRaw

        if try fetch() == nil {
            context.insert(entity)
        }
        try context.save()
    }

    /// 読み込み
    func load() throws -> (
        queueIDs: [String],
        currentIndex: Int,
        playbackRate: Double,
        shuffleModeRaw: Int,
        repeatModeRaw: Int
    ) {
        guard let e = try fetch() else {
            return (
                [], 0,
                Constants.MusicPlayer.defaultPlaybackRate,
                MPMusicShuffleMode.off.rawValue,
                MPMusicRepeatMode.none.rawValue
            )
        }
        return (e.queueIDs, e.currentIndex, e.playbackRate, e.shuffleModeRaw, e.repeatModeRaw)
    }

    private func fetch() throws -> PlayerStateEntity? {
        let descriptor = FetchDescriptor<PlayerStateEntity>(
            predicate: #Predicate { $0.id == "default" }
        )
        return try context.fetch(descriptor).first
    }
}
