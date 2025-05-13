import SwiftUI
import Inject
import MusicKit

struct SearchRowView: View {
    let song: Song
    
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
            Button {
            } label: {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .foregroundColor(.secondary)
            }
        }
    }
}
struct SearchView: View {
    @ObserveInjection var inject
    @StateObject private var vm = SearchViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text("検索")
                        .font(.largeTitle)
                        .bold()
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                HStack {
                    Image(systemName: "magnifyingglass")
                    TextField("Search", text: $vm.searchText)
                        .onChange(of: vm.searchText) {
                            vm.updateFilter()
                        }
                    Spacer()
                    Image(systemName: "mic.fill")
                }
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                if !vm.searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                    List {
                        ForEach(vm.filteredSongs, id: \.id) { song in
                            NavigationLink(value: song) {
                                SearchRowView(song: song)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                    .navigationDestination(for: Song.self) { song in
                        MusicPlayerView(
                            songIDs: vm.filteredSongs.map { $0.id },
                            initialIndex: vm.filteredSongs.firstIndex { $0.id == song.id} ?? 0
                        )
                    }
                } else {
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .enableInjection()
        }
    }
}

