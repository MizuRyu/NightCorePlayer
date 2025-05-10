import SwiftUI
import Inject

struct SpeedControlButton: View {
    let label: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.callout)
                .foregroundColor(.white)
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .background(color)
                .cornerRadius(8)
        }
    }
}

struct MusicPlayerView: View {
    // Injection 発生を監視するwrapper
    @ObserveInjection var inject
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
                    value: Binding(
                        get: { viewModel.currentTime },
                        set: { viewModel.seek(to: $0 ) }
                    ),
                    in: 0...viewModel.musicDuration
                )
                .accentColor(.indigo)
                Text(timeString(from: viewModel.musicDuration))
                    .font(.caption2)
            }
            .padding(.horizontal)
            // ▶️ 再生コントロール
            HStack(spacing: 48) {
                Button { viewModel.rewind15() } label: {
                    Image(systemName: "gobackward.15")
                        .font(.title2)
                }
                Button (action: {
                    viewModel.isPlaying ? viewModel.pause() : viewModel.play()
                }) {
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

            // ⚙️ 倍速調整
            VStack(spacing: 10) {
                Slider(
                    value: Binding(
                        get: { viewModel.rate },
                        set: { viewModel.setRate(to: $0) }
                    ),
                    in: 0.5...3.0,
                    step: 0.01
                )
                .frame(width: 340)
                .accentColor(.indigo)
                // Slider のメーター線
                .overlay(
                    GeometryReader { geo in
                        let divisions = 10
                        ForEach(0...divisions, id: \.self) { i in
                            let x = geo.size.width * CGFloat(i) / CGFloat(divisions)
                            Rectangle()
                                .frame(width: 1, height: 10)
                                .foregroundColor(.secondary.opacity(0.6))
                                .position(x: x, y: geo.size.height/2)
                        }
                    }
                )
                .padding(.horizontal)
                
                
                HStack(spacing: 12) {
                    SpeedControlButton(label: "-0.1", color: .red) {
                        viewModel.changeRate(by: -0.1)
                    }
                    SpeedControlButton(label: "-0.01", color: .red) {
                        viewModel.changeRate(by: -0.01)
                    }
                    Text(String(format: "%.2fx", viewModel.rate))
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .frame(minWidth: 40)
                    SpeedControlButton(label: "+0.01", color: .green) {
                        viewModel.changeRate(by: +0.01)
                    }
                    SpeedControlButton(label: "+0.1", color: .green) {
                        viewModel.changeRate(by: +0.1)
                    }
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .enableInjection()
    }

    // —————————————————————
    // MARK: – Helpers
    // —————————————————————
    private func timeString(from seconds: Double) -> String {
        let s = Int(seconds)
        return String(format: "%02d:%02d", s/60, s%60)
    }
}

#Preview {
    MusicPlayerView()
}
