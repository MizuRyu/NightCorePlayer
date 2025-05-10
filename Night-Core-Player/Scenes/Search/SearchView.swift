import SwiftUI
import Inject

struct SearchView: View {
    @ObserveInjection var inject
    
    var body: some View {
        VStack {
            Text("search")
                .font(.title2)
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .enableInjection()
    }
}
