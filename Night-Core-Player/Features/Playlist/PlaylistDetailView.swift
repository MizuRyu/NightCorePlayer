import SwiftUI
import Inject
import MusicKit

struct PlaylistDetailView: View {
    @ObserveInjection var inject
    @StateObject private var vm: PlaylistDetailViewModel
    @EnvironmentObject private var nav: PlayerNavigator
    @EnvironmentObject private var playerVM: MusicPlayerViewModel

    init(pl: Playlist,
         musicKitService: MusicKitService = MusicKitServiceImpl()) {
        _vm = StateObject(wrappedValue: PlaylistDetailViewModel(
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
                    // Action Buttons
                    HStack(spacing: 16) {
                        Button {
                            playerVM.loadPlaylist(
                                songs: vm.songs,
                                startAt: 0,
                                autoPlay: true
                            )
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "play.fill")
                                Text("再生")
                            }
                            .font(.body)
                            .frame(maxWidth: .infinity, minHeight: 42)
                        }
                        .foregroundColor(.indigo)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)

                        Button {
                            playerVM.loadPlaylist(
                                songs: vm.songs.shuffled(),
                                startAt: 0,
                                autoPlay: true
                            )
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "shuffle")
                                Text("シャッフル")
                            }
                            .font(.body)
                            .frame(maxWidth: .infinity, minHeight: 42)
                        }
                        .foregroundColor(.indigo)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
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
                        MusicPlayerView(
                            songs: vm.songs,
                            initialIndex: vm.songs.firstIndex { $0.id == song.id } ?? 0
                        )
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
}