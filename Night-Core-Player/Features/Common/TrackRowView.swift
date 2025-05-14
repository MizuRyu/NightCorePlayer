import SwiftUI
import Inject

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
