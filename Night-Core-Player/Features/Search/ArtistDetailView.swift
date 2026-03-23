import SwiftUI
import Inject
import MusicKit

struct ArtistDetailView: View {
    @ObserveInjection var inject
    @State private var vm: ArtistDetailViewModel
    @Environment(PlayerNavigator.self) private var nav
    @Environment(MusicPlayerViewModel.self) private var playerVM

    init(artist: Artist, musicKitService: any MusicKitService) {
        _vm = State(initialValue: ArtistDetailViewModel(
            artist: artist,
            musicKitService: musicKitService
        ))
    }

    var body: some View {
        Group {
            if vm.isLoading {
                ProgressView("読み込み中…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let msg = vm.errorMessage {
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
            } else {
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        actionButton(title: "再生", systemImage: "play.fill") {
                            Task {
                                await vm.loadAllAvailable()
                                playerVM.loadPlaylist(
                                    songs: vm.songs,
                                    startAt: 0,
                                    autoPlay: true
                                )
                                nav.selectedTab = .player
                            }
                        }
                        actionButton(title: "シャッフル", systemImage: "shuffle") {
                            Task {
                                await vm.loadAllAvailable()
                                playerVM.loadPlaylist(
                                    songs: vm.songs.shuffled(),
                                    startAt: 0,
                                    autoPlay: true
                                )
                                nav.selectedTab = .player
                            }
                        }
                    }
                    .padding(.horizontal)

                    List {
                        ForEach(vm.songs, id: \.id) { song in
                            Button {
                                let idx = vm.songs.firstIndex { $0.id == song.id } ?? 0
                                playerVM.loadPlaylist(
                                    songs: vm.songs,
                                    startAt: idx,
                                    autoPlay: true
                                )
                                nav.selectedTab = .player
                            } label: {
                                SongRowView(song: song)
                            }
                            .onAppear {
                                Task { await vm.loadMoreIfNeeded(currentSong: song) }
                            }
                        }

                        if vm.isLoadingMore {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color(.systemBackground))
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle(vm.artist.name)
        .navigationBarTitleDisplayMode(.large)
        .enableInjection()
        .task { await vm.load() }
    }

    private func actionButton(
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
