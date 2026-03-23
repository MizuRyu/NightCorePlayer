import SwiftUI

extension Constants {

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
            public static let miniMusicPlayerHeight: CGFloat = 55.0
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

    public enum Playlist {
        public static let iconSystemNameSize: CGFloat = 15.0
    }
}
