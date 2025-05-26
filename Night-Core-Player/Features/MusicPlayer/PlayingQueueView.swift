import SwiftUI
import Inject
import MusicKit

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

struct HistorySectionView: View {
    @EnvironmentObject private var vm: MusicPlayerViewModel
    
    var body: some View {
        // history が空ならセクション自体を表示しない
        if !vm.history.isEmpty {
            Text("再生履歴")
                .font(.body).bold()
                .foregroundStyle(.primary)
                .padding(.vertical, 8)
            
            ForEach(Array(vm.history.enumerated()), id: \.offset) { idx, song in
                PlayingQueueItemRowView(
                    song: song,
                    isCurrent: idx == vm.currentIndex
                )
            }
        }
    }
}

struct QueueSectionView: View {
    @EnvironmentObject private var vm: MusicPlayerViewModel
    
    var body: some View {
        // スクロールのターゲットとしてidを設定
        Text("次に再生")
            .font(.body).bold()
            .foregroundStyle(.primary)
            .padding(.vertical, 8)
            .id("queueHeader")
        
        ForEach(Array(vm.musicPlayerQueue.enumerated()), id: \.element.id) { idx, song in
            PlayingQueueItemRowView(
                song: song,
                isCurrent: idx == vm.currentIndex
            )
            .overlay(alignment: .trailing) {
                Image(systemName: "line.3.horizontal")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.trailing, 8)
            }
            // ③ タップ領域全体を拾う
            .contentShape(Rectangle())
            // ④ 背景のハイライト
            .listRowBackground(
                idx == vm.currentIndex
                ? Color.indigo.opacity(0.1)
                : Color.clear
            )
        }
        .onMove { indices, newOffset in
            guard let src = indices.first else { return }
            let dst = newOffset > src ? newOffset - 1 : newOffset
            vm.moveQueueItem(from: src, to: dst)
        }
        .onDelete(perform: vm.removeQueueItems)
    }
}

struct CombinedListView: View {
    @EnvironmentObject private var vm: MusicPlayerViewModel
    
    var body: some View {
        ScrollViewReader { proxy in
            List {
                // 履歴セクション（ヘッダ、行ともにSectionに含まれる）
                HistorySectionView()
                    .environmentObject(vm)
                
                // 再生キューセクション
                QueueSectionView()
                    .environmentObject(vm)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .onAppear {
                // 最初に必ず「次に再生」セクションを先頭に表示
                proxy.scrollTo("queueHeader", anchor: .top)
            }
        }
    }
}

struct PlayingQueueView: View {
    @EnvironmentObject private var vm: MusicPlayerViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .frame(width: 40, height: 5)
                .foregroundColor(Color.secondary.opacity(0.6))
                .padding(.vertical, 8)
            
            NowPlayingHeaderView()
                .environmentObject(vm)
            
            HStack {
                Spacer()
                Text("\(vm.musicPlayerQueue.count) items")
                Spacer()
                Text(vm.remainingTimeString)
                Spacer()
            }
            .padding(.horizontal)
            .foregroundColor(.secondary)
            
            CombinedListView()
                .environmentObject(vm)
            
            Spacer()
            
            MusicPlayerControlsView()
                .environmentObject(vm)
                .padding(.vertical, 60)
        }
        .background(Color(.systemBackground))
    }
}
