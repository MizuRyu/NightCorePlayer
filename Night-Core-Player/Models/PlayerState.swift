import Foundation
import SwiftData
import MediaPlayer

@Model
final class PlayerState {
    @Attribute(.unique) var id: String = "default"

    /// キューに入っている Song.id.rawValue の配列を JSON 化して保存
    var queueIDsData: Data
    var currentIndex: Int

    var playbackRate: Double
    var shuffleModeRaw: Int
    var repeatModeRaw: Int

    init(
        queueIDs: [String] = [],
        currentIndex: Int = 0,
        playbackRate: Double = Constants.MusicPlayer.defaultPlaybackRate,
        shuffleModeRaw: Int = MPMusicShuffleMode.off.rawValue,
        repeatModeRaw: Int = MPMusicRepeatMode.none.rawValue
    ) {
        self.queueIDsData  = try! JSONEncoder().encode(queueIDs)
        self.currentIndex  = currentIndex
        self.playbackRate  = playbackRate
        self.shuffleModeRaw = shuffleModeRaw
        self.repeatModeRaw  = repeatModeRaw
    }

    /// デコードして返す
    var queueIDs: [String] {
        (try? JSONDecoder().decode([String].self, from: queueIDsData)) ?? []
    }
}
