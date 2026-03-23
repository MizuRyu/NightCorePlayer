import SwiftUI
import Inject
import MusicKit

struct SongRowView: View {
    @ObserveInjection var inject
    let song: Song
    
    var body: some View {
        HStack {
            if song.artwork != nil {
                ArtworkImage(song.artwork!, width: 48, height: 48)
                    .cornerRadius(6)
            } else {
                Image(systemName: "music.note")
                    .resizable()
                    .frame(width: 48, height: 48)
                    .cornerRadius(6)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.body)
                Text(song.artistName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            SongContextMenu(song: song)
        }
        .padding(.vertical, 8)
        .enableInjection()
    }
}
