import SwiftUI
import Inject

struct PlaylistDetailView: View {
    @ObserveInjection var inject
    let category: PlaylistCategory
    @StateObject private var vm: PlaylistDetailViewModel
    
    init(category: PlaylistCategory) {
        self.category = category
        _vm = StateObject(wrappedValue: PlaylistDetailViewModel(category: category))
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            HStack(spacing: 16) {
                Button {
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
            .padding(.horizontal, 32)
                
            List(vm.tracks) { track in
                TrackRowView(track: track)
            }
            .listStyle(PlainListStyle())
        }
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.large)
        .enableInjection()
    }
}
