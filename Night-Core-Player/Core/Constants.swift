import SwiftUI
import MusicKit

public enum Constants {
    
    public enum MusicAPI {
        public static let musicKitSearchLimit: Int = 25
        public static let playlistsLoadLimit: Int = 10
    }
    
    public enum Timing {
        public static let searchDebounce: Int = 500
        public static let musicPlayerTick: Int = 500
    }
    
    public enum DefaultValues {
        public static let marqueeScrollSpeed: Double = 30.0
        public static let musicPlayerInitialDuration: Double = 240.0
    }
    
    public enum MarqueeText {
        public static let defaultSpeed: Double = 30.0
        public static let defaultSpacing: CGFloat = 20.0
        public static let defaultDelay: Double = 3.0
    }
    
    public enum UI {
        public enum CornerRadius {
            public static let standard: CGFloat = 8.0
            public static let medium: CGFloat = 10.0
            public static let large: CGFloat = 6.0
        }
        
        public enum Spacing {
            public static let standard: CGFloat = 8.0
            public static let medium: CGFloat = 12.0
            public static let large: CGFloat = 16.0
            public static let extraLarge: CGFloat = 20.0
            public static let playerControls: CGFloat = 48.0
        }
        
        public enum FrameSize {
            public static let artworkSmall: CGFloat = 48.0
            public static let artworkMedium: CGFloat = 300.0
            public static let buttonMinHeight: CGFloat = 42.0
            public static let speedControlSliderWidth: CGFloat = 340.0
            public static let playlistIconWidth: CGFloat = 24.0
        }
        
        public enum Padding {
            public static let standard: CGFloat = 8.0
            public static let medium: CGFloat = 10.0
            public static let large: CGFloat = 16.0
            public static let playlistDividerLeading: CGFloat = 36.0
        }
        
        public enum Font {
            // Add public static let as needed
        }
        
        public enum Opacity {
            public static let sliderTickMark: Double = 0.6
        }
    }
    
    public enum AppColors {
        public static let accent: Color = .indigo
        public static let decreaseButton: Color = .red
        public static let increaseButton: Color = .green
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
    
    public enum Playlist {
        public static let iconSystemNameSize: CGFloat = 15.0
    }
    
    public enum Settings {
        public enum ItemKeys {
            public static let playbackSpeed = "settings_item_playback_speed"
            public static let tempo = "settings_item_tempo"
            public static let termsAndPrivacy = "settings_item_terms_and_privacy"
            public static let feedback = "settings_item_feedback"
            public static let review = "settings_item_review"
        }
        public enum SectionHeaders {
            public static let sound = "settings_section_sound"
            public static let other = "settings_section_other"
        }
    }
    
    public enum TabView {
        public enum MusicPlayer {
            public static let title = "Player"
            public static let systemImage = "music.note"
        }
        public enum Search {
            public static let title = "Search"
            public static let systemImage = "magnifyingglass"
        }
        public enum Playlist {
            public static let title = "Playlist"
            public static let systemImage = "list.bullet"
        }
        public enum Settings {
            public static let title = "Settings"
            public static let systemImage = "gearshape"
        }
    }
    
    public enum Localization {
        public static let playingNow = "Playing Now"
        public static let play = "再生"
        public static let shuffle = "シャッフル"
        public static let settings = "設定"
        public static let search = "検索"
        public static let playlist = "プレイリスト"
    }
    
}
