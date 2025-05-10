import SwiftUI
import Inject

struct PlaylistView: View {
    @ObserveInjection var inject
    
    var body: some View {
        VStack {
            Text("PlayListView")
                .font(.title2)
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .enableInjection()
    }
}

