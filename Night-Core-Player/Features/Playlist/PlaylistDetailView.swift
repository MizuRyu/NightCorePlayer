import SwiftUI
import Inject
import MusicKit

struct PlaylistDetailView: View {
    @ObserveInjection var inject
    @State private var vm: PlaylistDetailViewModel
    @Environment(PlayerNavigator.self) private var nav
    @Environment(MusicPlayerViewModel.self) private var playerVM

    init(pl: Playlist, musicKitService: any MusicKitService) {
        _vm = State(initialValue: PlaylistDetailViewModel(
            playlist: pl,
            musicKitService: musicKitService
        ))
    }

    var body: some View {
        Group {
            // Loading State
            if vm.isLoading {
                ProgressView("読み込み中…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            // Error State
            else if let msg = vm.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(msg)
                        .multilineTextAlignment(.center)
                    Button("リトライ") {
                        Task { await vm.load() }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            // Loaded State
            else {
                VStack(spacing: 16) {
                    // アクションボタン
                    HStack(spacing: 16) {
                        playlistActionButton(
                            title: "再生",
                            systemImage: "play.fill"
                        ) {
                            playerVM.loadPlaylist(
                                songs: vm.songs,
                                startAt: 0,
                                autoPlay: true
                            )
                        }
                        playlistActionButton(
                            title: "シャッフル",
                            systemImage: "shuffle"
                        ) {
                            playerVM.loadPlaylist(
                                songs: vm.songs.shuffled(),
                                startAt: 0,
                                autoPlay: true
                            )
                        }
                    }
                    .padding(.horizontal)

                    // Song List
                    List(vm.songs, id: \.id) { song in
                        Button {
                            let idx = vm.songs.firstIndex { $0.id == song.id } ?? 0
                            playerVM.loadPlaylist(
                                songs: vm.songs,
                                startAt: idx,
                                autoPlay: true
                            )

                            nav.songs = vm.songs
                            nav.initialIndex = idx
                            nav.selectedTab = .player
                        } label: {
                            SongRowView(song: song)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color(.systemBackground))
                    .navigationDestination(for: Song.self) { song in
                        Text(song.title)
                    }
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle(vm.playlist.name)
        .navigationBarTitleDisplayMode(.large)
        .enableInjection()
        .task { await vm.load() }
    }

    /// プレイリスト操作ボタンの共通スタイル
    private func playlistActionButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.body)
            .frame(maxWidth: .infinity, minHeight: Constants.UI.FrameSize.buttonMinHeight)
        }
        .foregroundColor(Constants.AppColors.accent)
        .background(Color(.systemGray5))
        .cornerRadius(Constants.UI.CornerRadius.standard)
    }
}