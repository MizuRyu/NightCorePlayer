import SwiftUI
import MusicKit

struct ArtistRowView: View {
    let artist: Artist

    var body: some View {
        HStack {
            if let url = artist.artwork?.url(width: 48, height: 48) {
                AsyncImage(url: url) { image in
                    image.resizable()
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.fill")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .frame(width: 48, height: 48)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Circle())
            }

            Text(artist.name)
                .font(.body)
                .foregroundColor(.primary)

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
