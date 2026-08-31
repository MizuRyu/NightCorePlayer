import SwiftUI
import Inject
import NightCoreDomain

struct SettingsPlaybackSpeedView: View {
    @ObserveInjection var inject
    var settingsVM: SettingsViewModel

    @State private var currentSpeed: Double

    init(settingsVM: SettingsViewModel) {
        self.settingsVM = settingsVM
        _currentSpeed = State(initialValue: settingsVM.defaultRate)
    }

    var body: some View {
        List {
            Text("Playback Speed")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.leading, 16)
                .padding(.top, 8)
                .listRowSeparator(.hidden)

            HStack {
                Text("×\(String(format: "%.2f", currentSpeed))")
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .frame(alignment: .leading)

                Spacer()

                Stepper(
                    value: $currentSpeed,
                    in: Constants.MusicPlayer.minPlaybackRate...Constants.MusicPlayer.maxPlaybackRate,
                    step: Constants.MusicPlayer.rateStepSmall
                ) {
                    EmptyView()
                }
                .onChange(of: currentSpeed) { _, newVal in
                    settingsVM.updateDefaultRate(to: newVal)
                }
                .labelsHidden()

            }
            .listRowSeparator(.hidden)
            .padding(.horizontal, 16)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("On app launch, music will play at the configured playback speed.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("※Recommended ×1.15 ~ ×1.25")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.leading, 16)
            .padding(.vertical, 0)
            .listRowSeparator(.hidden)

        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, Constants.UI.FrameSize.miniMusicPlayerContentInset, for: .scrollContent)
        .background(Color(.systemBackground))
        .enableInjection()
    }
}
