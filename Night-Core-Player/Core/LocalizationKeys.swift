import Foundation

extension Constants {

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
