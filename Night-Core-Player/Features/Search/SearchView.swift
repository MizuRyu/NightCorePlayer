import SwiftUI
import Inject
import MusicKit

struct SearchRowView: View {
    let song: Song
    @EnvironmentObject private var playerVM: MusicPlayerViewModel
    
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
                    playerVM.insertNext(song)
                    // デバッグ用ログ
                    print("🎯 insertNext called for: \(song.title) — \(song.artistName)")
                    print("📦 current queue:")
                    for (i, s) in playerVM.musicPlayerQueue.enumerated() {
                        print("   [\(i)] \(s.title) — \(s.artistName)")
                    }
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
            .onTapGesture {
                playerVM.playNow(song)
            }
        }
        .padding(.vertical, 4)
    }
}
struct SearchView: View {
    @ObserveInjection var inject
    @StateObject private var vm = SearchViewModel()
    @EnvironmentObject private var nav: PlayerNavigator
    @EnvironmentObject private var playerVM: MusicPlayerViewModel
        
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
                            let idx = vm.songs.firstIndex(where: { $0.id == song.id}) ?? 0
                            playerVM.loadPlaylist(songs: vm.songs, startAt: idx, autoPlay: true)
                            nav.songs = vm.songs
                            nav.initialIndex = vm.songs.firstIndex(where: { $0.id == song.id }) ?? 0
                            nav.selectedTab = .player
                        } label: {
                            SearchRowView(song: song)
                        }
                    }
                
                    .listStyle(PlainListStyle())
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

