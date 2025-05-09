import SwiftUI

struct MusicPlayerView: View {
    @StateObject var viewModel = MusicPlayerViewModel()

    var body: some View {
        VStack(spacing: 16) {
            // 🚀 タイトル
            Text("Playing Now")
                .font(.headline)
                .padding(.top, 8)

            // 🖼️ アートワーク
            viewModel.artworkImage
                .resizable()
                .scaledToFit()
                .cornerRadius(12)
                .padding(.horizontal)

            // ⏮️ 曲情報 + ⏭️
            HStack(spacing: 24) {
                Button { viewModel.previousTrack() } label: {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                }
                VStack {
                    Text(viewModel.trackTitle)
                        .font(.title3)
                    Text(viewModel.artistName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Button { viewModel.nextTrack() } label: {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                }
            }

            // 📊 シークバー
            HStack {
                Text(timeString(from: viewModel.currentTime))
                    .font(.caption2)
                Slider(
                    value: $viewModel.currentTime,
                    in: 0...viewModel.musicDuration
                )
                Text(timeString(from: viewModel.musicDuration))
                    .font(.caption2)
            }
            .padding(.horizontal)

            // ⚙️ 倍速調整
            HStack(spacing: 12) {
                Button("-0.10") { viewModel.changeRate(by: -0.10) }
                    .foregroundColor(.red)
                    .font(.caption)
                Button("-0.01") { viewModel.changeRate(by: -0.01) }
                    .foregroundColor(.red)
                    .font(.caption)
                Text(String(format: "%.2fx", viewModel.rate))
                    .font(.caption)
                Button("+0.01") { viewModel.changeRate(by: +0.01) }
                    .foregroundColor(.green)
                    .font(.caption)
                Button("+0.10") { viewModel.changeRate(by: +0.10) }
                    .foregroundColor(.green)
                    .font(.caption)
            }

            // ▶️ 再生コントロール
            HStack(spacing: 48) {
                Button { viewModel.rewind15() } label: {
                    Image(systemName: "gobackward.15")
                        .font(.title2)
                }
                Button { viewModel.togglePlayPause() } label: {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.largeTitle)
                }
                Button { viewModel.forward15() } label: {
                    Image(systemName: "goforward.15")
                        .font(.title2)
                }
            }
            .padding(.vertical, 8)

            Spacer()

            // ⭐️ Tab Bar（ダミー）
            HStack {
                ForEach(0..<5) { idx in
                    Spacer()
                    Image(systemName: idx == 0 ? "star.fill" : "star")
                    Spacer()
                }
            }
            .padding(.vertical, 8)
            .background(Color(UIColor.systemBackground).shadow(radius: 1))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // —————————————————————
    // MARK: – Helpers
    // —————————————————————
    private func timeString(from seconds: Double) -> String {
        let s = Int(seconds)
        return String(format: "%02d:%02d", s/60, s%60)
    }
}

