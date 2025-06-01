import SwiftUI
import MusicKit

/// 楽曲のコンテキストメニュー
struct SongContextMenu: View {
    let song: Song
    @EnvironmentObject private var playerVM: MusicPlayerViewModel
    
    var body: some View {
        Menu {
            Button("再生を次に追加") {
                playerVM.insertNext(song)
            }
            Divider()
            Button("キャンセル", role: .cancel) {}
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
}
