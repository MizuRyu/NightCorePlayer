import SwiftUI
import Inject
import MusicKit

struct MusicPlayerControlsView: View {
    @ObserveInjection var inject
    @Environment(MusicPlayerViewModel.self) private var vm
    
    var body: some View {
        VStack(spacing: 16) {
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
    @Environment(MusicPlayerViewModel.self) private var vm
    
    var body: some View {
        HStack {
            vm.artworkImage
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
    @Environment(MusicPlayerViewModel.self) private var vm
    @State private var showDeleteAlert = false

    var body: some View {
        if !vm.history.isEmpty {
            HStack {
                Text("再生履歴")
                    .font(.body).bold()
                    .foregroundStyle(.primary)
                    .padding(.vertical, 8)
                Spacer()
                Button {
                    showDeleteAlert = true
                } label: {
                    Label("履歴を削除", systemImage: "trash")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.plain)
                .font(.subheadline)
                .foregroundColor(.red)
                .disabled(vm.history.isEmpty)
            }
            .padding(.vertical, 8)
            .alert("履歴をすべて削除しますか？", isPresented: $showDeleteAlert) {
                Button("削除", role: .destructive) {
                    vm.clearHistory()
                }
                Button("キャンセル", role: .cancel) { }
            }
                ForEach(Array(vm.history.enumerated()), id: \.offset) { idx, song in
                    PlayingQueueItemRowView(
                        song: song,
                        isCurrent: false
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        vm.playNowNext(song)
                    }
                }
            }
        }
    }

struct QueueSectionView: View {
    @Environment(MusicPlayerViewModel.self) private var vm
    
    var body: some View {
        Text("次に再生")
            .font(.body).bold()
            .foregroundStyle(.primary)
            .padding(.vertical, 8)
            .id("queueHeader")
                
        ForEach(Array(vm.currentQueue.enumerated()), id: \.element.id) { _, song in
            PlayingQueueItemRowView(
                song: song,
                isCurrent: false
            )
            .overlay(alignment: .trailing) {
                Image(systemName: "line.3.horizontal")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.trailing, 8)
            }
            .contentShape(Rectangle())
            .onTapGesture{ vm.playNowNext(song) }
            .listRowBackground(Color.clear)
        }
        .onMove(perform: vm.moveQueueItem)
        .onDelete(perform: vm.removeQueueItem)
    }
}

struct CombinedListView: View {
    @Environment(MusicPlayerViewModel.self) private var vm
    
    var body: some View {
        ScrollViewReader { proxy in
            List {
                HistorySectionView()
                QueueSectionView()
                
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .onAppear {
                proxy.scrollTo("queueHeader", anchor: .top)
            }
            .onChange(of: vm.currentIndex) {
                withAnimation {
                    proxy.scrollTo(vm.currentIndex, anchor: .center)
                }
            }
            .onChange(of: vm.history.count) {
                withAnimation(.none) {
                    proxy.scrollTo("queueHeader", anchor: .top)
                }
            }
        }
    }
}
    
struct PlayingQueueView: View {
    @Environment(MusicPlayerViewModel.self) private var vm
    
    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .frame(width: 40, height: 5)
                .foregroundColor(Color.secondary.opacity(0.6))
                .padding(.vertical, 8)
            
            NowPlayingHeaderView()
            
            HStack {
                Spacer()
                Text("\(vm.musicPlayerQueue.count) items")
                Spacer()
                Text(vm.remainingTimeString)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
            .foregroundColor(.secondary)
            
            CombinedListView()
            
            Spacer()
            
            MusicPlayerControlsView()
                .padding(.vertical, 60)
        }
        .background(Color(.systemBackground))
    }
}
