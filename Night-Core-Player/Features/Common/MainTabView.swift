import SwiftUI
import Inject
import MusicKit
struct MainTabView: View {
    @ObserveInjection var inject
    @StateObject private var nav      = PlayerNavigator()
    @StateObject private var playerVM = MusicPlayerViewModel(service: MusicPlayerServiceImpl())
    @StateObject private var keyboard = KeyboardResponder()
    
    // MiniPlayerの要素の高さ
    private let miniPlayerHeight: CGFloat = Constants.UI.FrameSize.miniMusicPlayerHeight
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $nav.selectedTab) {
                MusicPlayerView()
                    .tabItem { Label("Player", systemImage: "music.note") }
                    .tag(PlayerNavigator.Tab.player)
                    .safeAreaPadding(.bottom, miniPlayerHeight)
                
                SearchView()
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }
                    .tag(PlayerNavigator.Tab.search)
                    .safeAreaPadding(.bottom, miniPlayerHeight)
                
                PlaylistView()
                    .tabItem { Label("Playlist", systemImage: "list.bullet") }
                    .tag(PlayerNavigator.Tab.playlist)
                    .safeAreaPadding(.bottom, miniPlayerHeight)
                
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape") }
                    .tag(PlayerNavigator.Tab.settings)
                    .safeAreaPadding(.bottom, miniPlayerHeight)
            }
            .environmentObject(nav)
            .environmentObject(playerVM)
            
            // MiniPlayer を下端（safe area）のすぐ上に差し込む
            // タブバー分の余白は .padding(.bottom) で調整
            if nav.selectedTab != .player && !keyboard.isVisible {
                MiniMusicPlayerView()
                    .environmentObject(nav)
                    .environmentObject(playerVM)
                    .frame(height: miniPlayerHeight)    // ★高さ固定
                    .background(.ultraThinMaterial)    // 背景マテリアル
                    .cornerRadius(8)
                    .shadow(radius: 1)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation {
                            nav.selectedTab = .player
                        }
                    }
                    .padding(.bottom, /* タブバー高さ */ 55)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut, value: playerVM.isPlaying)
            }
        }
        .enableInjection()
    }
}
