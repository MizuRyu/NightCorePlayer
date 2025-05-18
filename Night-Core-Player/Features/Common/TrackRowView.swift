import SwiftUI
import Inject
import MusicKit

struct TrackRowView: View {
    @ObserveInjection var inject
    let track: Track
    
    var body: some View {
        HStack {
            Image(track.artworkName)
                .resizable()
                .frame(width: 48, height: 48)
                .cornerRadius(6)
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.body)
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
        .padding(.vertical, 8)
        .enableInjection()
    }
}

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
            Button {
            } label: {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .enableInjection()
    }
}
