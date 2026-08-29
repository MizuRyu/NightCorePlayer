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
        public static let normalPlaybackRate: Double = 1.0
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

    public enum Recommendation {
        // 設計 (docs/specs/RECOMMENDATION.md) の「毎日20曲」に一致させる
        public static let defaultLimit: Int = 20
        // 配合と探索幅 (docs/specs/RECOMMENDATION.md)
        public static let discoveryRatio: Double = 0.3
        public static let topArtistCount: Int = 5
        public static let similarArtistsPerArtist: Int = 3
        public static let recentlyPlayedFetchLimit: Int = 30
    }

    public enum Logging {
        public static let subsystem: String = "MizuRyu.Night-Core-Player"
    }

    public enum Allowance {
        public static let trialDays: Int = 7
        public static let dailyFreeSeconds: TimeInterval = 3600
        public static let rewardSeconds: TimeInterval = 1800
        public static let proPromptRewardCount: Int = 5
    }

    public enum Ads {
        // Debug は Google 公式のテストユニットID、Release は本番ユニットID(rewarded_balance)
        #if DEBUG
        public static let rewardedUnitID: String = "ca-app-pub-3940256099942544/1712485313"
        #else
        public static let rewardedUnitID: String = "ca-app-pub-4210364120390329/6068775358"
        #endif
    }
}
