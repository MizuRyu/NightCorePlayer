import SwiftUI
import Inject

struct SearchRowView: View {
    let track: Track
    
    var body: some View {
        HStack {
            Image(track.artworkName)
                .resizable()
                .frame(width: 48, height: 48)
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.body)
                    .foregroundColor(.primary)
                Text(track.artist)
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
                    ForEach(vm.filteredTracks) { track in
                        SearchRowView(track: track)
                    }
                }
                .listStyle(PlainListStyle())
            } else {
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .enableInjection()
    }
}

