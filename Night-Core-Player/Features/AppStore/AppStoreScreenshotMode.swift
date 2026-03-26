import SwiftUI

enum AppStoreScreenshotScene: String, CaseIterable {
    case player
    case search
    case playlist

    static let launchFlag = "-app-store-screenshot-scene"

    static var current: Self? {
        let arguments = ProcessInfo.processInfo.arguments

        guard
            let flagIndex = arguments.firstIndex(of: launchFlag),
            arguments.indices.contains(flagIndex + 1)
        else {
            return nil
        }

        return Self(rawValue: arguments[flagIndex + 1])
    }

    var fileStem: String { rawValue }
}

struct AppStoreScreenshotRootView: View {
    let scene: AppStoreScreenshotScene

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.96, green: 0.98, blue: 1.0),
                    Color(red: 0.92, green: 0.95, blue: 1.0),
                    Color(red: 0.95, green: 0.93, blue: 0.99)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                screenshotHeader

                switch scene {
                case .player:
                    AppStorePlayerScreenshotView()
                case .search:
                    AppStoreSearchScreenshotView()
                case .playlist:
                    AppStorePlaylistScreenshotView()
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .preferredColorScheme(.light)
    }

    private var screenshotHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("NightCore Player")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(headerTitle)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }

            Spacer()

            Text("Apple Music Required")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.indigo)
                .clipShape(Capsule())
        }
        .padding(.top, 12)
        .padding(.bottom, 20)
    }

    private var headerTitle: String {
        switch scene {
        case .player:
            "Now playing in Nightcore"
        case .search:
            "Search and queue instantly"
        case .playlist:
            "Jump through your playlists"
        }
    }
}

private struct AppStorePlayerScreenshotView: View {
    var body: some View {
        VStack(spacing: 18) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.indigo, Color.cyan, Color.pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 340)
                .overlay {
                    VStack(spacing: 18) {
                        Image("imgAssets1")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 210, height: 210)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .shadow(color: Color.black.opacity(0.18), radius: 18, y: 8)

                        VStack(spacing: 6) {
                            Text("Blue Horizon")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.white)
                            Text("Luna Echo")
                                .font(.headline)
                                .foregroundStyle(Color.white.opacity(0.88))
                        }
                    }
                    .padding(.top, 26)
                }

            VStack(spacing: 16) {
                VStack(spacing: 10) {
                    HStack(spacing: 14) {
                        Text("01:18")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)

                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.black.opacity(0.08))
                                Capsule()
                                    .fill(Color.indigo)
                                    .frame(width: proxy.size.width * 0.42)
                            }
                        }
                        .frame(height: 8)

                        Text("03:42")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 28) {
                        screenshotButton("gobackward.15")
                        screenshotButton("backward.fill")
                        Circle()
                            .fill(Color.indigo)
                            .frame(width: 72, height: 72)
                            .overlay {
                                Image(systemName: "pause.fill")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(Color.white)
                            }
                        screenshotButton("forward.fill")
                        screenshotButton("goforward.15")
                    }
                }

                HStack(spacing: 10) {
                    rateChip("-0.1", color: .red.opacity(0.9))
                    rateChip("-0.01", color: .red.opacity(0.72))
                    Text("1.30x")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.indigo)
                        .frame(minWidth: 72)
                    rateChip("+0.01", color: .green.opacity(0.72))
                    rateChip("+0.1", color: .green.opacity(0.9))
                }
            }
            .padding(20)
            .background(.white.opacity(0.84))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            screenshotFooter(
                title: "Fine-tune playback speed",
                subtitle: "Keep the queue moving while dialing in your preferred Nightcore tempo."
            )
        }
    }

    private func screenshotButton(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.title2.weight(.semibold))
            .foregroundStyle(.indigo)
            .frame(width: 44, height: 44)
            .background(Color.indigo.opacity(0.08))
            .clipShape(Circle())
    }

    private func rateChip(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(color)
            .clipShape(Capsule())
    }
}

private struct AppStoreSearchScreenshotView: View {
    private let songs = [
        ("Starlight Rush", "Astra Nova", "1.25x"),
        ("Velocity Dreams", "Kairo", "1.30x"),
        ("Skyline Hearts", "Mira Lane", "1.15x"),
        ("Neon Carousel", "Sora Pulse", "1.20x")
    ]

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                Text("nightcore mix")
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "waveform")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(.white.opacity(0.88))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(spacing: 12) {
                ForEach(Array(songs.enumerated()), id: \.offset) { index, song in
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: gradientColors(index: index),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 62, height: 62)
                            .overlay {
                                Image(systemName: "music.note")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.white.opacity(0.92))
                            }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(song.0)
                                .font(.headline.weight(.semibold))
                            Text(song.1)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(song.2)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.indigo)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.indigo.opacity(0.09))
                            .clipShape(Capsule())
                    }
                    .padding(14)
                    .background(.white.opacity(0.88))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }

            screenshotFooter(
                title: "Find tracks fast",
                subtitle: "Search results stay focused on the songs you want to queue and speed up."
            )
        }
    }

    private func gradientColors(index: Int) -> [Color] {
        switch index {
        case 0:
            [Color.pink, Color.orange]
        case 1:
            [Color.indigo, Color.cyan]
        case 2:
            [Color.mint, Color.teal]
        default:
            [Color.purple, Color.blue]
        }
    }
}

private struct AppStorePlaylistScreenshotView: View {
    private let playlists = [
        ("Late Night Boost", "24 songs", "imgAssets1"),
        ("Hyper Pop Drill", "18 songs", "imgAssets2"),
        ("Focus Sprint", "32 songs", "imgAssets1")
    ]

    var body: some View {
        VStack(spacing: 18) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.18, green: 0.22, blue: 0.54), Color(red: 0.49, green: 0.31, blue: 0.83)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(alignment: .leading, spacing: 10) {
                    Text("Ready-made playlists")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Queue favorites, revisit recently played tracks, and keep the energy up.")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.84))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(24)
            }
            .frame(height: 220)

            VStack(spacing: 12) {
                ForEach(Array(playlists.enumerated()), id: \.offset) { _, playlist in
                    HStack(spacing: 14) {
                        Image(playlist.2)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        VStack(alignment: .leading, spacing: 6) {
                            Text(playlist.0)
                                .font(.headline.weight(.semibold))
                            Text(playlist.1)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(.white.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
            }

            screenshotFooter(
                title: "Pick a vibe and press play",
                subtitle: "Playlists, history, and queue controls stay one tap away."
            )
        }
    }
}

private func screenshotFooter(title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Text(title)
            .font(.title3.weight(.bold))
        Text(subtitle)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(20)
    .background(.white.opacity(0.82))
    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
}
