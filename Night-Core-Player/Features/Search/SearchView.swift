import SwiftUI
import Inject
import MusicKit

struct SearchRowView: View {
    let song: Song
    @State private var isShowingPopover = false
    
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
            Menu {
                Button("再生を次に追加") {
                    // TODO: 再生キューに追加ロジック
                }
                Button("ライブラリに追加") {
                    // TODO: ライブラリに追加ロジック
                }
                Divider()
                Button("キャンセル", role: .cancel) {
                }
            } label: {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .foregroundColor(.secondary)
                    .padding(8)
            }
            .menuStyle(BorderlessButtonMenuStyle())
        }
        .padding(.vertical, 4)
    }
}
struct SearchView: View {
    @ObserveInjection var inject
    @StateObject private var vm = SearchViewModel()
    @EnvironmentObject private var nav: PlayerNavigator
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    TextField("曲名・アーティスト名", text: $vm.query)
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
                
                if vm.isLoading {
                    ProgressView().padding(.top, 40)
                } else if !vm.songs.isEmpty {
                    List(vm.songs, id: \.id) { song in
                        Button {
                            nav.songs = vm.songs
                            nav.initialIndex = vm.songs.firstIndex(where: { $0.id == song.id }) ?? 0
                            nav.selectedTab = .player
                        } label: {
                            SearchRowView(song: song)
                        }
                    }
                
                    .listStyle(PlainListStyle())
                    .navigationDestination(for: Song.self) { song in
                        MusicPlayerView(
                            songs: vm.songs,
                            initialIndex: vm.songs.firstIndex { $0.id == song.id} ?? 0
                        )
                    }
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scrollContentBackground(.hidden)
            .background(Color(.systemBackground))
            .navigationTitle("検索")
            .navigationBarTitleDisplayMode(.large)
            .enableInjection()
        }
    }
}

