import SwiftUI
import MusicKit

struct SongContextMenu: View {
    let song: Song
    @Environment(MusicPlayerViewModel.self) private var playerVM

    var body: some View {
        Menu {
            Button {
                playerVM.playNow(song)
            } label: {
                Label("Play This Song", systemImage: "play.fill")
            }
            Button {
                playerVM.insertNext(song)
            } label: {
                Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
            }
        } label: {
            Image(systemName: "ellipsis")
                .rotationEffect(.degrees(90))
                .foregroundColor(.secondary)
                .padding(8)
        }
        .menuStyle(BorderlessButtonMenuStyle())
    }
}
