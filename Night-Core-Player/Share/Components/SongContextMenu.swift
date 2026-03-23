import SwiftUI
import MusicKit

/// 楽曲のコンテキストメニュー
struct SongContextMenu: View {
    let song: Song
    @Environment(MusicPlayerViewModel.self) private var playerVM
    
    var body: some View {
        Menu {
            Button {
                playerVM.playNow(song)
            } label: {
                Label("この曲を再生", systemImage: "play.fill")
            }
            Button {
                playerVM.insertNext(song)
            } label: {
                Label("次に再生", systemImage: "text.line.first.and.arrowtriangle.forward")
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
