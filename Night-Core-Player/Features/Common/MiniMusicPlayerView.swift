import SwiftUI
import Inject

struct MiniMusicPlayerView: View {
    @ObserveInjection var inject
    @EnvironmentObject private var nav: PlayerNavigator
    @EnvironmentObject private var vm: MusicPlayerViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // プログレスバー
            GeometryReader { geo in
                let progress = vm.duration > 0
                ? vm.currentTime / vm.duration
                : 0
                Capsule()
                    .fill(Color.indigo)
                    .frame(width: geo.size.width * CGFloat(progress), height: 2)
                    .offset(y:geo.size.height - 2)
            }
            .frame(height: 2)
            
            HStack(spacing: 12) {
                vm.artwork
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .cornerRadius(4)
                
                MarqueeText(
                    text: vm.title,
                    font: .subheadline,
                    idleTextAlignment: .leading,
                    visibleWidth: 200,
                    speed: 30,
                    spacingBetweenTexts: 20,
                    delayBeforeScroll: 2
                )
                Spacer()
                
                Button(action: vm.previousTrack) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color.indigo)
                }
                Button(action: vm.playPauseTrack) {
                    Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color.indigo)
                }
                Button(action: vm.nextTrack) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color.indigo)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal)
            .padding(.trailing, 8)
        }
        .frame(maxWidth: .infinity)
        .enableInjection()
    }
}
