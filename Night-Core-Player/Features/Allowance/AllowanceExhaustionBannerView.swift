import SwiftUI

/// 残高が尽きた瞬間に出す非モーダルバナー。曲末までの猶予は続くが、
/// 何も起きないと「残高0でも再生できるバグ」に見えるため、その場で知らせる(#104)
struct AllowanceExhaustionBannerView: View {
    let viewModel: AllowanceSheetViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                viewModel.presentFromExhaustionBanner()
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Free time used up — sped-up playback stops after this song.")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Normal speed stays free. Tap to add time.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .multilineTextAlignment(.leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // VoiceOverでも「再生時間を追加」ダイアログへのタップだと伝わるようにする
            .accessibilityLabel(Text("Add Playback Time"))

            Spacer(minLength: 8)

            Button {
                viewModel.dismissExhaustionBanner()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .accessibilityLabel(Text("Close"))
            .accessibilityIdentifier("allowance_exhaustion_banner_close_button")
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .shadow(radius: 4)
        .padding(.horizontal, 16)
        .accessibilityIdentifier("allowance_exhaustion_banner")
    }
}
