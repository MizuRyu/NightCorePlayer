import SwiftUI
import MusicKit

struct PlayingQueueItemRowView: View {
    let song: Song
    let isCurrent: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // (song.artwork ?? Image(systemName: "music.note"))
            Image(systemName: "music.note")
                .scaledToFit()
                .frame(width: 44, height: 44)
                .cornerRadius(6)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.subheadline)
                    .foregroundColor(isCurrent ? .indigo : .primary)
                    .lineLimit(1)
                Text(song.artistName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
