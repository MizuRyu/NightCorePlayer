import SwiftUI
import MusicKit

struct PlayingQueueItemRowView: View {
    let song: Song
    let isCurrent: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            if let url = song.artwork?.url(width: 44, height: 44) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    default:
                        Image(systemName: "music.note")
                            .resizable()
                    }
                }
                .frame(width: 44, height: 44)
                .cornerRadius(6)
                
                // artworkがなければDefautアイコン
            } else {
                Image(systemName: "music.note")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(6)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(song.artistName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .listRowSeparator(.hidden)
    }
}
