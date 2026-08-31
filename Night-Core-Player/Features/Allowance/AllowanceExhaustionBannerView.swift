import SwiftUI

/// 残高が尽きた瞬間に出す非モーダルバナー。曲末までの猶予は続くが、
/// 何も起きないと「残高0でも再生できるバグ」に見えるため、その場で知らせる(#104)
struct AllowanceExhaustionBannerView: View {
    let viewModel: AllowanceSheetViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Free time used up — sped-up playback stops after this song.")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("Normal speed stays free. Tap to add time.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .multilineTextAlignment(.leading)

            Spacer(minLength: 8)

            Button {
                viewModel.dismissExhaustionBanner()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .accessibilityIdentifier("allowance_exhaustion_banner_close_button")
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .shadow(radius: 4)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.presentFromExhaustionBanner()
        }
        .accessibilityIdentifier("allowance_exhaustion_banner")
    }
}
