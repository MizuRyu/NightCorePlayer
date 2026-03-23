import SwiftUI
import Inject
import MusicKit
struct MainTabView: View {
    @ObserveInjection var inject
    @Environment(PlayerNavigator.self) private var nav
    @Environment(MusicPlayerViewModel.self) private var playerVM
    @Environment(SettingsViewModel.self) private var settingsVM
    @Environment(KeyboardResponder.self) private var keyboard
    
    // MiniPlayerの要素の高さ
    private let miniPlayerHeight: CGFloat = Constants.UI.FrameSize.miniMusicPlayerHeight
    
    var body: some View {
        @Bindable var nav = nav
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
            
            if nav.selectedTab != .player && !keyboard.isVisible {
                MiniMusicPlayerView()
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
