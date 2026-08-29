import SwiftUI

struct AllowanceSheetView: View {
    let viewModel: AllowanceSheetViewModel

    var body: some View {
        VStack(spacing: 20) {
            header

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            options

            Button("Close") {
                viewModel.close()
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            .accessibilityIdentifier("allowance_close_button")
        }
        .padding(24)
        .accessibilityIdentifier("allowance_sheet")
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 6) {
            Text(viewModel.showProPromptPitch ? "+30 Minutes Added" : "Today's Free Playback Time Is Used Up")
                .font(.title3)
                .fontWeight(.semibold)
            Text(viewModel.showProPromptPitch
                ? "You've watched 5 ads. Go Pro and you'll never need to again."
                : "Normal-speed playback is still free")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .multilineTextAlignment(.center)
    }

    // MARK: - Options

    private var options: some View {
        VStack(spacing: 0) {
            optionRow(
                icon: "play.rectangle.fill",
                title: "Watch a Video",
                badge: "+30 min",
                detail: "Adds playback time for today",
                isBusy: viewModel.isWatchingAd,
                isEnabled: !viewModel.showProPromptPitch && !viewModel.isWatchingAd,
                action: { viewModel.watchAdForReward() }
            )
            .accessibilityIdentifier("allowance_reward_button")

            Divider()
                .padding(.leading, 56)

            optionRow(
                icon: "infinity",
                title: "Go Pro",
                badge: "One-time",
                detail: "Unlimited playback, no ads",
                isBusy: viewModel.isPurchasing,
                isEnabled: !viewModel.isPurchasing,
                action: { viewModel.purchasePro() }
            )
            .accessibilityIdentifier("allowance_pro_button")
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func optionRow(
        icon: String,
        title: LocalizedStringKey,
        badge: LocalizedStringKey,
        detail: LocalizedStringKey,
        isBusy: Bool,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.indigo)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.body)
                            .foregroundColor(.primary)
                        badgeLabel(badge)
                    }
                    Text(detail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                if isBusy {
                    ProgressView()
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.4)
    }

    private func badgeLabel(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(Color(.tertiarySystemFill))
            )
    }
}
