import SwiftUI
import Inject
import MusicKit

struct PlaylistView: View {
    @ObserveInjection var inject
    @Environment(PlaylistViewModel.self) private var vm
    @Environment(\.musicKitService) private var musicKitService
    
    var body: some View {
        NavigationStack {
            content
                .navigationTitle("プレイリスト")
                .navigationDestination(for: PlaylistRowModel.self) { row in
                    PlaylistDetailView(pl: row.playlist, musicKitService: musicKitService)
                }
        }
        .task { await vm.load() }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .enableInjection()
    }
    
    @ViewBuilder
    private var content: some View {
        if vm.isLoading {
            loadingView
        }
        else if let msg = vm.errorMessage {
            errorView(msg)
        }
        else {
            listView
        }
    }
    
    private var loadingView: some View {
        ProgressView("読み込み中...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ msg: String) -> some View {
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
    
    private var listView: some View {
        List {
            ForEach(vm.rows) { row in
                VStack(spacing: 0) {
                    NavigationLink(value: row) {
                        HStack(spacing: 12) {
                            if let artwork = row.artwork {
                                ArtworkImage(artwork, width: 56, height: 56)
                                    .cornerRadius(4)
                            } else {
                                Image(systemName: "music.note")
                                    .frame(width: 56, height: 56, alignment: .leading)
                                    .foregroundColor(.indigo)
                                    .cornerRadius(4)
                            }
                            Text(row.title)
                                .font(.title3)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                    }
                    Divider()
                        .padding(.leading, 36)
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemBackground))
    }
}


