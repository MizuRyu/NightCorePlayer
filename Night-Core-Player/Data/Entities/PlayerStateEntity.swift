import Foundation
import SwiftData
import MediaPlayer

@Model
final class PlayerStateEntity {
    @Attribute(.unique) var id: String = "default"

    var queueIDs: [String]
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
        self.queueIDs       = queueIDs
        self.currentIndex   = currentIndex
        self.playbackRate   = playbackRate
        self.shuffleModeRaw = shuffleModeRaw
        self.repeatModeRaw  = repeatModeRaw
    }
}
