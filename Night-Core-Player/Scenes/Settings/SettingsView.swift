import SwiftUI
import Inject

struct SettingsView: View {
    @ObserveInjection var inject
    
    var body: some View {
        VStack {
            Text("Settigs")
                .font(.title2)
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .enableInjection()
    }
}
