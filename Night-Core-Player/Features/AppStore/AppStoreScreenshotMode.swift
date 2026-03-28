import SwiftUI

enum AppStoreScreenshotScene: String, CaseIterable {
    case player
    case search
    case playlist
    case queue

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

// MARK: - Root

struct AppStoreScreenshotRootView: View {
    let scene: AppStoreScreenshotScene

    var body: some View {
        Group {
            switch scene {
            case .player:
                AppStorePlayerScreenshotView()
            case .search:
                AppStoreSearchScreenshotView()
            case .playlist:
                AppStorePlaylistScreenshotView()
            case .queue:
                AppStoreQueueScreenshotView()
            }
        }
    }
}

// MARK: - Player

private struct AppStorePlayerScreenshotView: View {
    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Playing Now")
                    .font(.headline)
                    .padding(.top, 8)

                Spacer()

                Image("imgAssets1")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 250, height: 250)
                    .cornerRadius(12)
                    .padding(.horizontal)

                HStack(spacing: 24) {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                        .foregroundColor(.indigo)

                    VStack(spacing: 2) {
                        Text("Blue Horizon")
                            .font(.title3)
                            .lineLimit(1)
                        Text("Luna Echo")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .frame(width: 100)

                    Image(systemName: "forward.fill")
                        .font(.title2)
                        .foregroundColor(.indigo)
                }

                HStack {
                    Text("01:18")
                        .font(.caption2)
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(uiColor: .systemGray5))
                            Capsule()
                                .fill(Color.indigo)
                                .frame(width: proxy.size.width * 0.35)
                        }
                    }
                    .frame(height: 4)
                    Text("03:42")
                        .font(.caption2)
                }
                .padding(.horizontal)

                HStack(spacing: 48) {
                    Image(systemName: "gobackward.15")
                        .font(.title2)
                        .foregroundColor(.indigo)
                    Image(systemName: "pause.fill")
                        .font(.largeTitle)
                        .foregroundColor(.indigo)
                    Image(systemName: "goforward.15")
                        .font(.title2)
                        .foregroundColor(.indigo)
                }
                .padding(.vertical, 8)

                Spacer(minLength: 20)

                VStack(spacing: 10) {
                    ZStack {
                        Capsule()
                            .fill(Color(uiColor: .systemGray5))
                            .frame(width: 340, height: 4)
                        HStack {
                            Capsule()
                                .fill(Color.indigo)
                                .frame(width: 340 * 0.32, height: 4)
                            Spacer()
                        }
                        .frame(width: 340)
                    }
                    .frame(width: 340)

                    HStack(spacing: 12) {
                        rateButton("-0.1", color: .red)
                        rateButton("-0.01", color: .red)
                        Text("1.30x")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .frame(minWidth: 40)
                        rateButton("+0.01", color: .green)
                        rateButton("+0.1", color: .green)
                    }
                }

                Image(systemName: "list.bullet")
                    .font(.title2)
                    .foregroundColor(.indigo)
                    .frame(maxWidth: .infinity, minHeight: 30)
            }
        }
    }

    private func rateButton(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.callout)
            .foregroundColor(.white)
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .background(color)
            .cornerRadius(8)
    }
}

// MARK: - Search

private struct AppStoreSearchScreenshotView: View {
    private let songs: [(String, String, String)] = [
        ("Starlight Rush", "Astra Nova", "imgAssets2"),
        ("Velocity Dreams", "Kairo", "imgAssets1"),
        ("Skyline Hearts", "Mira Lane", "imgAssets2"),
        ("Neon Carousel", "Sora Pulse", "imgAssets1")
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("nightcore mix")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "mic.fill")
                }
                .padding(10)
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 8)

                List {
                    ForEach(Array(songs.enumerated()), id: \.offset) { _, song in
                        HStack {
                            Image(song.2)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 48, height: 48)
                                .cornerRadius(8)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(song.0)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Text(song.1)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "ellipsis")
                                .rotationEffect(.degrees(90))
                                .foregroundColor(.secondary)
                                .padding(8)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)

                Spacer()
            }
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("検索")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Playlist

private struct AppStorePlaylistScreenshotView: View {
    private let playlists: [(String, String)] = [
        ("Late Night Boost", "imgAssets1"),
        ("Hyper Pop Drill", "imgAssets2"),
        ("Focus Sprint", "imgAssets1"),
        ("Morning Drive", "imgAssets2"),
        ("Weekend Vibes", "imgAssets1")
    ]

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(playlists.enumerated()), id: \.offset) { _, playlist in
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Image(playlist.1)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 56, height: 56)
                                .cornerRadius(4)

                            Text(playlist.0)
                                .font(.title3)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.vertical, 12)

                        Divider()
                            .padding(.leading, 36)
                    }
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("プレイリスト")
        }
    }
}

// MARK: - Queue

private struct AppStoreQueueScreenshotView: View {
    private let queueSongs: [(String, String, String)] = [
        ("Velocity Dreams", "Kairo", "imgAssets1"),
        ("Skyline Hearts", "Mira Lane", "imgAssets2"),
        ("Neon Carousel", "Sora Pulse", "imgAssets1"),
        ("Midnight Pulse", "Yoru", "imgAssets2"),
        ("Crystal Wave", "Aoi Sora", "imgAssets1")
    ]

    private let historySongs: [(String, String, String)] = [
        ("Starlight Rush", "Astra Nova", "imgAssets2"),
        ("Dawn Breaker", "Hikari", "imgAssets1")
    ]

    var body: some View {
        VStack(spacing: 0) {
            // ドラッグハンドル
            Capsule()
                .frame(width: 40, height: 5)
                .foregroundColor(Color.secondary.opacity(0.6))
                .padding(.vertical, 8)

            // Now Playing ヘッダー
            HStack {
                Image("imgAssets1")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 70, height: 70)
                    .cornerRadius(6)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Blue Horizon")
                        .font(.body)
                        .lineLimit(1)
                    Text("Luna Echo")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            // キュー情報
            HStack {
                Spacer()
                Text("\(queueSongs.count) items")
                Spacer()
                Spacer()
                Text("18:32")
                Spacer()
            }
            .font(.subheadline)
            .padding(.horizontal)
            .padding(.bottom, 8)
            .foregroundColor(.secondary)

            // リスト
            List {
                // 再生履歴
                HStack {
                    Text("再生履歴")
                        .font(.body).bold()
                        .foregroundStyle(.primary)
                        .padding(.vertical, 8)
                    Spacer()
                    Label("履歴を削除", systemImage: "trash")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
                .padding(.vertical, 8)

                ForEach(Array(historySongs.enumerated()), id: \.offset) { _, song in
                    queueRow(title: song.0, artist: song.1, image: song.2)
                }

                // 次に再生
                Text("次に再生")
                    .font(.body).bold()
                    .foregroundStyle(.primary)
                    .padding(.vertical, 8)

                ForEach(Array(queueSongs.enumerated()), id: \.offset) { _, song in
                    HStack(spacing: 0) {
                        queueRow(title: song.0, artist: song.1, image: song.2)
                        Image(systemName: "line.3.horizontal")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding(.trailing, 8)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            Spacer()

            // Shuffle / Repeat / AutoPlay ボタン
            HStack(spacing: 16) {
                Spacer()
                queueToggle("shuffle", active: true)
                queueToggle("repeat", active: false)
                queueToggle("infinity", active: true)
                Spacer()
            }
            .padding(.top, 12)
            .padding(.bottom, 4)

            // 再生コントロール
            VStack(spacing: 16) {
                VStack(spacing: 4) {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(uiColor: .systemGray5))
                            Capsule()
                                .fill(Color.indigo)
                                .frame(width: proxy.size.width * 0.35)
                        }
                    }
                    .frame(height: 4)
                    .padding(.horizontal)
                    HStack {
                        Text("01:18")
                        Spacer()
                        Text("03:42")
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                }
                .padding(.vertical, 15)

                HStack(spacing: 20) {
                    Image(systemName: "gobackward.15").font(.title2)
                    Image(systemName: "backward.fill").font(.title2)
                    Image(systemName: "pause.fill").font(.largeTitle)
                    Image(systemName: "forward.fill").font(.title2)
                    Image(systemName: "goforward.15").font(.title2)
                }
                .foregroundColor(.indigo)
                .padding(.vertical, 8)
            }
            .padding(.bottom, 60)
        }
        .background(Color(uiColor: .systemBackground))
    }

    private func queueRow(title: String, artist: String, image: String) -> some View {
        HStack(spacing: 12) {
            Image(image)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .cornerRadius(6)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(artist)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .listRowSeparator(.hidden)
    }

    private func queueToggle(_ systemName: String, active: Bool) -> some View {
        Image(systemName: systemName)
            .font(.title3)
            .foregroundColor(active ? .indigo : .secondary)
            .frame(width: 40, height: 40)
            .background(
                Circle()
                    .fill(active ? Color.indigo.opacity(0.15) : Color.clear)
            )
    }
}
