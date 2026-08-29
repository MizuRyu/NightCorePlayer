import SwiftUI

struct AllowanceSheetView: View {
    let viewModel: AllowanceSheetViewModel

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text(viewModel.showProPromptPitch ? "+30 Minutes Added" : "Today's Free Playback Time Is Used Up")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("Normal-speed playback is still free")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .multilineTextAlignment(.center)

            if viewModel.showProPromptPitch {
                Text("You've watched 5 ads. Go Pro and you'll never need to again.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button {
                    viewModel.watchAdForReward()
                } label: {
                    if viewModel.isWatchingAd {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Watch a Video for +30 Minutes")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.showProPromptPitch || viewModel.isWatchingAd)
                .accessibilityIdentifier("allowance_reward_button")

                Button {
                    viewModel.purchasePro()
                } label: {
                    if viewModel.isPurchasing {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Go Unlimited with Pro (One-Time Purchase)")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isPurchasing)
                .accessibilityIdentifier("allowance_pro_button")

                Button("Close") {
                    viewModel.close()
                }
                .accessibilityIdentifier("allowance_close_button")
            }
        }
        .padding()
        .accessibilityIdentifier("allowance_sheet")
    }
}
