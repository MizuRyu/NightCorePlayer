import SwiftUI
import Inject
import MusicKit

struct SearchRowView: View {
    let song: Song
    @Environment(MusicPlayerViewModel.self) private var playerVM

    var body: some View {
        HStack {
            if let url = song.artwork?.url(width: 48, height: 48) {
                AsyncImage(url: url) { image in
                    image.resizable()
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 48, height: 48)
                .cornerRadius(8)
            } else {
                Image(systemName: "music.note")
                    .frame(width: 48, height: 48)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.body)
                    .foregroundColor(.primary)
                Text(song.artistName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            SongContextMenu(song: song)
        }
        .padding(.vertical, 4)
    }
}

struct SearchView: View {
    @ObserveInjection var inject
    @Environment(SearchViewModel.self) private var vm
    @Environment(PlayerNavigator.self) private var nav
    @Environment(MusicPlayerViewModel.self) private var playerVM
    @Environment(\.musicKitService) private var musicKitService
    @FocusState private var isSearchBarFocused: Bool

    var body: some View {
        @Bindable var vm = vm
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    TextField("曲名・アーティスト名", text: $vm.query)
                        .focused($isSearchBarFocused)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .submitLabel(.search)
                    Spacer()
                    Image(systemName: "mic.fill")
                }
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 8)
                .onChange(of: nav.searchBarFocusRequested) { _, requested in
                    if requested {
                        isSearchBarFocused = true
                        nav.searchBarFocusRequested = false
                    }
                }

                if vm.isLoading {
                    ProgressView().padding(.top, 40)
                } else if !vm.artists.isEmpty || !vm.songs.isEmpty {
                    List {
                        ForEach(vm.artists, id: \.id) { artist in
                            NavigationLink(value: artist) {
                                ArtistRowView(artist: artist)
                            }
                        }

                        ForEach(vm.songs, id: \.id) { song in
                            Button {
                                let idx = vm.songs.firstIndex(where: { $0.id == song.id }) ?? 0
                                playerVM.loadPlaylist(songs: vm.songs, startAt: idx, autoPlay: true)
                                nav.selectedTab = .player
                            } label: {
                                SearchRowView(song: song)
                            }
                            .onAppear {
                                Task { await vm.loadMoreSongsIfNeeded(currentSong: song) }
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
                    .listStyle(PlainListStyle())
                } else if vm.query.isEmpty && !vm.searchHistory.isEmpty {
                    searchHistoryView
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scrollContentBackground(.hidden)
            .background(Color(.systemBackground))
            .navigationTitle("検索")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: Artist.self) { artist in
                ArtistDetailView(artist: artist, musicKitService: musicKitService)
            }
            .alert("エラー", isPresented: Binding<Bool>(
                get: { vm.errorMessage != nil },
                set: { if !$0 { vm.errorMessage = nil } }
            )) {
                Button("OK") { vm.errorMessage = nil }
            } message: {
                Text(vm.errorMessage ?? "")
            }
            .enableInjection()
        }
    }

    // MARK: - Search History

    private var searchHistoryView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("最近の検索")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Button("すべて削除") {
                    vm.clearSearchHistory()
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 8)

            List {
                ForEach(Array(vm.searchHistory.enumerated()), id: \.element) { index, keyword in
                    HStack {
                        Text(keyword)
                            .font(.body)
                            .foregroundColor(.primary)
                        Spacer()
                        Button {
                            vm.removeHistoryItem(at: index)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .accessibilityLabel("履歴を削除")
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        vm.selectHistoryItem(keyword)
                    }
                }
            }
            .listStyle(.plain)
        }
    }
}
