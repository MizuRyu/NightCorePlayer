import SwiftUI

public enum Constants {

    public enum MusicAPI {
        public static let musicKitSearchLimit: Int = 25
        public static let playlistsLoadLimit: Int = 10
    }

    public enum History {
        public static let maxHistoryCount: Int = 100
    }

    public enum Timing {
        public static let searchDebounce: Int = 500
        public static let musicPlayerTick: Int = 500
    }

    public enum MusicPlayer {
        public static let minPlaybackRate: Double = 0.5
        public static let maxPlaybackRate: Double = 3.0
        public static let step: Double = 0.5
        public static let defaultPlaybackRate: Double = 1.15
        public static let rateStepLarge: Double = 0.1
        public static let rateStepSmall: Double = 0.01
        public static let skipSeconds: Double = 15.0
        public static let sliderDivisions: Int = 10
        public static let artworkSize: CGFloat = 300
        public static let updateInterval: TimeInterval = 0.5
    }

    public enum RepeatMode: Sendable {
        case none
        case one
        case all
    }
}
