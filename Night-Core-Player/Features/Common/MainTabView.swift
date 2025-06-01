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
            
            if nav.selectedTab != .player && !keyboard.isVisible {
                MiniMusicPlayerView()
                    .environmentObject(nav)
                    .environmentObject(playerVM)
                    .frame(height: miniPlayerHeight)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    .shadow(radius: 1)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation {
                            nav.selectedTab = .player
                        }
                    }
                    .padding(.bottom, 55)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut, value: playerVM.isPlaying)
            }
        }
        .enableInjection()
    }
}
