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
    ) {
        let entity = fetch() ?? PlayerState()
        do {
            entity.queueIDsData = try JSONEncoder().encode(queueIDs)
        } catch {
            print("⚠️ PlayerState encode error:", error)
        }
        entity.currentIndex  = currentIndex
        entity.playbackRate  = playbackRate
        entity.shuffleModeRaw = shuffleModeRaw
        entity.repeatModeRaw  = repeatModeRaw

        if fetch() == nil {
            context.insert(entity)
        }
        saveContext()
    }

    /// 読み込み
    func load() -> (
        queueIDs: [String],
        currentIndex: Int,
        playbackRate: Double,
        shuffleModeRaw: Int,
        repeatModeRaw: Int
    ) {
        guard let e = fetch() else {
            return (
                [], 0,
                Constants.MusicPlayer.defaultPlaybackRate,
                MPMusicShuffleMode.off.rawValue,
                MPMusicRepeatMode.none.rawValue
            )
        }
        return (e.queueIDs, e.currentIndex, e.playbackRate, e.shuffleModeRaw, e.repeatModeRaw)
    }
    

    private func fetch() -> PlayerState? {
        let descriptor = FetchDescriptor<PlayerState>(
            predicate: #Predicate { $0.id == "default" }
        )
        return (try? context.fetch(descriptor))?.first
    }

    private func saveContext() {
        do {
            try context.save()
        } catch {
            print("⚠️ PlayerState save error:", error)
        }
    }
}
