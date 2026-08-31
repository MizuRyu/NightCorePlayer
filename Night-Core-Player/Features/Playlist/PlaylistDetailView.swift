import Inject
import MusicKit
import NightCoreDomain
import SwiftUI

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
            if vm.isLoading {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "music.note.list")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No displayable songs in this playlist")
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let msg = vm.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(msg)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await vm.load() }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        playlistActionButton(
                            title: String(localized: "Play"),
                            systemImage: "play.fill"
                        ) {
                            playerVM.loadPlaylist(
                                songs: vm.songs,
                                startAt: 0,
                                autoPlay: true
                            )
                        }
                        playlistActionButton(
                            title: String(localized: "Shuffle"),
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
                    .contentMargins(.bottom, Constants.UI.FrameSize.miniMusicPlayerContentInset, for: .scrollContent)
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
