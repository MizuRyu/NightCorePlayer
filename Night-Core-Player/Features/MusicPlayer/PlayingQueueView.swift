import SwiftUI
import Inject

struct MusicPlayerControlsView: View {
    @ObserveInjection var inject
    @EnvironmentObject private var vm: MusicPlayerViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // 📊 シークバー
            VStack(spacing: 4) {
                Slider(
                    value: Binding(
                        get: { vm.currentTime },
                        set: { vm.seek(to: $0 ) }
                    ),
                    in: 0...vm.duration
                )
                .accentColor(.indigo)
                HStack {
                    Text(timeString(from: vm.currentTime))
                    Spacer()
                    Text(timeString(from: vm.duration))
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 15)
            // ▶️ 再生コントロール
            HStack(spacing: 32) {
                Button { vm.rewind15() } label: {
                    Image(systemName: "gobackward.15")
                        .font(.title2)
                }
                Button { vm.previousTrack() } label: {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                }
                Button { vm.playPauseTrack() } label: {
                    Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                        .font(.largeTitle)
                }
                Button { vm.nextTrack() } label: {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                }
                Button { vm.forward15() } label: {
                    Image(systemName: "goforward.15")
                        .font(.title2)
                }
            }
            .foregroundColor(.indigo)
            .padding(.vertical, 8)
            
        }
    }
}

struct NowPlayingHeaderView: View {
    @EnvironmentObject private var vm: MusicPlayerViewModel
    
    var body: some View {
        HStack {
            vm.artwork
                .resizable()
                .scaledToFit()
                .frame(width: 70, height: 70)
                .cornerRadius(6)
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.title)
                    .font(.body)
                    .lineLimit(1)
                Text(vm.artist)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        
    }
}

struct PlayingQueueView: View {
    @EnvironmentObject private var vm: MusicPlayerViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            
            // グレーのバー
            Capsule()
                .frame(width: 40, height: 5)
                .foregroundColor(Color.secondary.opacity(0.6))
                .padding(.top, 8)
                .padding(.bottom, 4)
            
            // 現在再生中の楽曲
            NowPlayingHeaderView()
            // — Header
            HStack {
                Spacer()
                Text("\(vm.musicPlayerQueue.count) items")
                Spacer()
                Text(vm.remainingTimeString)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .foregroundColor(.secondary)
            Text("次に再生")
                .font(.body)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                        
            // — List
            List {
                ForEach(Array(vm.musicPlayerQueue.enumerated()), id: \.element.id) { idx, song in
                    PlayingQueueItemRowView(
                        song: song,
                        isCurrent: idx == vm.currentIndex
                    )
                    .listRowBackground(
                        idx == vm.currentIndex
                        ? Color.indigo.opacity(0.1)
                        : Color.clear
                    )
                }
                .onMove { indices, newOffset in
                    guard let src = indices.first else { return }
                    let dst = newOffset > src
                    ? newOffset - 1
                    : newOffset
                    vm.moveQueueItem(from: src, to:  dst)
                }
                .deleteDisabled(true)
            }
            .listStyle(.plain)
            .environment(\.editMode, .constant(.active))
            
            Spacer()
            
            MusicPlayerControlsView()
                .environmentObject(vm)
                .padding(.top, 8)
                .padding(.bottom, 60)
        }
        .background(Color(.systemBackground))
        .enableInjection()
    }
    
}
