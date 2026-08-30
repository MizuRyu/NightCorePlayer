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
                viewModel.dismissByUser()
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            .disabled(viewModel.isBusy)
            .accessibilityIdentifier("allowance_close_button")
        }
        .padding(24)
        .accessibilityIdentifier("allowance_sheet")
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 6) {
            Text(headline)
                .font(.title3)
                .fontWeight(.semibold)
            Text(subheadline)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .multilineTextAlignment(.center)
    }

    private var headline: LocalizedStringKey {
        if viewModel.showProPromptPitch {
            return "+30 Minutes Added"
        }
        // 開いた経緯によって、何が起きたのか／何ができるのかを見出しで説明する
        switch viewModel.presentationReason {
        case .revertedToNormalRate:
            return "Switched Back to Normal Speed"
        case .addTime:
            return "Add Playback Time"
        case .exhausted:
            return "Today's Free Playback Time Is Used Up"
        }
    }

    private var subheadline: LocalizedStringKey {
        if viewModel.showProPromptPitch {
            return "You've watched 5 ads. Go Pro and you'll never need to again."
        }
        switch viewModel.presentationReason {
        case .revertedToNormalRate:
            return "Today's free playback time is used up. Add more time to speed up again."
        case .addTime:
            return "Watch a video or go Pro to extend today's speed-control time."
        case .exhausted:
            return "Normal-speed playback is still free"
        }
    }

    // MARK: - Options

    private var options: some View {
        VStack(spacing: 0) {
            optionRow(
                icon: "play.rectangle.fill",
                title: "Watch a Video",
                badge: "+30 min",
                detail: viewModel.rewardsRemainingToday > 0
                    ? "Adds playback time for today (\(viewModel.rewardsRemainingToday) left today)"
                    : "You've reached today's ad limit. It resets tomorrow.",
                isBusy: viewModel.isWatchingAd,
                isEnabled: !viewModel.showProPromptPitch && !viewModel.isWatchingAd
                    && viewModel.rewardsRemainingToday > 0,
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
