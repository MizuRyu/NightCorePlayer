import Foundation

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
        public static let artworkSize: Double = 300
        public static let updateInterval: TimeInterval = 0.5
    }

    public enum RepeatMode: Sendable {
        case none
        case one
        case all
    }

    public enum Recommendation {
        /// 設計 (docs/specs/RECOMMENDATION.md) の「毎日20曲」に一致させる
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
        /// 1日に視聴できるリワード広告の回数。AdMob 側に固定の上限はなく、
        /// 管理画面のフリークエンシーキャップも任意設定のため、上限はアプリ側で持つ。
        /// 無料枠1時間 + 30分×5回 = 最大3.5時間/日
        public static let dailyRewardLimit: Int = 5
    }

    public enum Ads {
        // Debug は Google 公式のテストユニットID、Release は本番ユニットID(rewarded_balance)
        #if DEBUG
            public static let rewardedUnitID: String = "ca-app-pub-3940256099942544/1712485313"
        #else
            public static let rewardedUnitID: String = "ca-app-pub-4210364120390329/6068775358"
        #endif
    }

    public enum Analytics {
        /// TelemetryDeckのApp IDは未発行(#68)。アカウント作成後、発行されたIDへ差し替える。
        /// このプレースホルダのままの間はAnalyticsServiceImplが初期化・送信ともno-opにする
        public static let placeholderAppID: String = "PLACEHOLDER-TELEMETRYDECK-APP-ID"
        public static let appID: String = placeholderAppID
    }
}
