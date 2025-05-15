import SwiftUI
import Inject
import MusicKit

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

// Sliderにメモリを表示するOverlay
struct SliderTickMarksOverlay: View {
    let minValue: Double = Constants.MusicPlayer.minPlaybackRate
    let maxValue: Double = Constants.MusicPlayer.maxPlaybackRate
    let step: Double = Constants.MusicPlayer.step

    var body: some View {
        GeometryReader { geo in
            let total = Int((maxValue - minValue) / step)
            ForEach(0...total, id: \.self) { i in
                let value  = minValue + Double(i) * step
                let ratio  = (value - minValue) / (maxValue - minValue)
                let xPos   = geo.size.width * ratio
                
                VStack(spacing: 4) {
                    // 数字（上）
                    Text(String(format: "%.1f", value))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    // 目盛り（下）
                    Rectangle()
                        .fill(Color.secondary.opacity(0.6))
                        .frame(width: 1, height: 8)
                }
                .position(x: xPos, y: max(0, geo.size.height/2 - 14))
            }
        }
        .allowsHitTesting(false)
    }
}

struct MusicPlayerView: View {
    // Injection 発生を監視するwrapper
    @ObserveInjection var inject
    @EnvironmentObject private var nav: PlayerNavigator
    @StateObject private var vm = MusicPlayerViewModel()
    
    
    init() {
        let clearImage = UIImage()
        UISlider.appearance().setThumbImage(clearImage, for: .normal)
    }
    
    init(songIDs: [MusicItemID], initialIndex: Int = 0) {
        _vm = StateObject(wrappedValue: MusicPlayerViewModel())
        let clearImage = UIImage()
        UISlider.appearance().setThumbImage(clearImage, for: .normal)
        vm.loadPlaylist(ids: songIDs, startAt: initialIndex)
    }

    var body: some View {
        VStack(spacing: 16) {
            // 🚀 タイトル
            Text("Playing Now")
                .font(.headline)
                .padding(.top, 8)
            Spacer()

            // 🖼️ アートワーク
            vm.artwork
                .resizable()
                .scaledToFit()
                .frame(width: 300, height: 300)
                .cornerRadius(12)
                .padding(.horizontal)
            // ⏮️ 曲情報 + ⏭️
            HStack(spacing: 24) {
                Button { vm.previousTrack() } label: {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                        .foregroundColor(.indigo)
                }
                
                VStack {
                    let titleHeight = UIFont.preferredFont(forTextStyle: .title3).lineHeight
                    let subtitleHeight = UIFont.preferredFont(forTextStyle: .subheadline).lineHeight
                    MarqueeText(
                        text: vm.title,
                        font: .title3,
                        visibleWidth: 100,
                        speed: 30,
                        spacingBetweenTexts: 20,
                        delayBeforeScroll: 3
                    )
                    .frame(width: 100, height: titleHeight)
                    .clipped()
                    MarqueeText(
                        text: vm.artist,
                        font: .subheadline,
                        visibleWidth: 100,
                        speed: Constants.MarqueeText.defaultSpeed,
                        spacingBetweenTexts: Constants.MarqueeText.defaultSpacing,
                        delayBeforeScroll: Constants.MarqueeText.defaultDelay
                    )
                    .foregroundColor(.secondary)
                    .frame(width: 100, height: subtitleHeight)
                    .clipped()
                }
                Button { vm.nextTrack() } label: {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                        .foregroundColor(.indigo)
                }
            }
            // 📊 シークバー
            HStack {
                Text(timeString(from: vm.currentTime))
                    .font(.caption2)
                Slider(
                    value: Binding(
                        get: { vm.currentTime },
                        set: { vm.seek(to: $0 ) }
                    ),
                    in: 0...vm.duration
                )
                .accentColor(.indigo)
                Text(timeString(from: vm.duration))
                    .font(.caption2)
            }
            .padding(.horizontal)
            // ▶️ 再生コントロール
            HStack(spacing: 48) {
                Button { vm.rewind15() } label: {
                    Image(systemName: "gobackward.15")
                        .font(.title2)
                        .foregroundColor(.indigo)
                }
                Button (action: {
                    vm.playPauseTrack()
                }) {
                    Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                        .font(.largeTitle)
                        .foregroundColor(.indigo)
                }
                Button { vm.forward15() } label: {
                    Image(systemName: "goforward.15")
                        .font(.title2)
                        .foregroundColor(.indigo)
                }
            }
            .padding(.vertical, 8)

            Spacer()

            // ⚙️ 倍速調整
            VStack(spacing: 10) {
                Slider(
                    value: Binding(
                        get: { vm.rate },
                        set: { vm.setRate(to: $0) }
                    ),
                    in: Constants.MusicPlayer.minPlaybackRate...Constants.MusicPlayer.maxPlaybackRate,
                    step: 0.01
                ) { editing in
                    if !editing { vm.setRate(to: vm.rate) }
                }
                
                .frame(width: 340)
                .accentColor(.indigo)
                .overlay(SliderTickMarksOverlay())
                .padding(.horizontal)
                
                
                HStack(spacing: 12) {
                    SpeedControlButton(label: "-\(Constants.MusicPlayer.rateStepLarge)", color: .red) {
                        vm.changeRate(by: -Constants.MusicPlayer.rateStepLarge)
                    }
                    SpeedControlButton(label: "-\(Constants.MusicPlayer.rateStepSmall)", color: .red) {
                        vm.changeRate(by: -Constants.MusicPlayer.rateStepSmall)
                    }
                    Text(String(format: "%.2fx", vm.rate))
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .frame(minWidth: 40)
                    SpeedControlButton(label: "+\(Constants.MusicPlayer.rateStepSmall)", color: .green) {
                        vm.changeRate(by: Constants.MusicPlayer.rateStepSmall)
                    }
                    SpeedControlButton(label: "+\(Constants.MusicPlayer.rateStepLarge)", color: .green) {
                        vm.changeRate(by: Constants.MusicPlayer.rateStepSmall)
                    }
                }
            }
            Spacer()
        }
        .onChange(of: nav.songIDs) { _, newIDs in
            vm.loadPlaylist(
                ids: newIDs,
                startAt: nav.initialIndex
            )
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

//#Preview {
//    MusicPlayerView()
//}
