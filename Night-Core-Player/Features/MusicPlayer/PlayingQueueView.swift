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

struct PlayingQueueView: View {
    @EnvironmentObject private var vm: MusicPlayerViewModel
    @Environment(\.dismiss) private var dismiss
    //
    //    private func move(from src: IndexSet, to dst: Int) {
    //        guard let i = src.first else { return }
    //        Task { await vm.moveQueueuItem(from: i, to: dst) }
    //    }
    //    private func delete(at offsets: IndexSet) {
    //        guard let i = offsets.first else { return }
    //        Task { await vm.removeQueueItem(at: i)}
    //    }
    //
    //    private var remainingTime: String {
    //        let remaining = vm.queue
    //            .enumerated()
    //            .filter { $0.offset >= vm.currentIndex }
    //            .map(\.element.duration)
    //            .reduce(0, +) / vm.playbackRate
    //        let m = Int(remaining) / 60
    //        let s = Int(remaining) % 60
    //        return String(format: "%02d:%02d", m, s)
    //    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            // グレーのバー
            Capsule()
                .frame(width: 40, height: 5)
                .foregroundColor(Color.secondary.opacity(0.6))
                .padding(.top, 8)
                .padding(.bottom, 4)
            
            // 現在再生中の楽曲
            HStack {
                Image(systemName: "music.note")
                    .scaledToFit()
                    .frame(width: 70, height: 70)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray, lineWidth: 1)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text("currentTitle")
                        .font(.body)
                        .lineLimit(1)
                    Text("currentArtist")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            // — Header
            HStack {
                Spacer()
                //                Text("\(vm.queue.count) items")
                Text("3 items")
                Spacer()
//                Text(remainingTime)
                Text("18 min")
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
//                ForEach(Array(vm.queue.enumerated()), id: \.element.id) { idx, song in
//                    PlayingQueueItemRowView(
//                        song: song,
//                        isCurrent: idx == vm.currentIndex
//                    )
//                }
                //                .onMove(perform: move)
                //                .onDelete(perform: delete)
                HStack(spacing: 12) {
                    // (song.artwork ?? Image(systemName: "music.note"))
                    Image(systemName: "music.note")
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .cornerRadius(6)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("title")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Text("artistName")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .listRowSeparator(.hidden)
                HStack(spacing: 12) {
                    // (song.artwork ?? Image(systemName: "music.note"))
                    Image(systemName: "music.note")
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .cornerRadius(6)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("title")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Text("artistName")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .listRowSeparator(.hidden)
                HStack(spacing: 12) {
                    // (song.artwork ?? Image(systemName: "music.note"))
                    Image(systemName: "music.note")
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .cornerRadius(6)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("title")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Text("artistName")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            
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
