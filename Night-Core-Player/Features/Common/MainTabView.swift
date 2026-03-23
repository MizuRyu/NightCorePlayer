import SwiftUI
import Inject
import MusicKit
struct MainTabView: View {
    @ObserveInjection var inject
    @Environment(PlayerNavigator.self) private var nav
    @Environment(MusicPlayerViewModel.self) private var playerVM
    @Environment(SettingsViewModel.self) private var settingsVM
    @Environment(KeyboardResponder.self) private var keyboard

    private let miniPlayerHeight: CGFloat = Constants.UI.FrameSize.miniMusicPlayerHeight

    private var showMiniPlayer: Bool {
        nav.selectedTab != .player && !keyboard.isVisible
    }

    var body: some View {
        @Bindable var nav = nav
        let tabBinding = Binding<PlayerNavigator.Tab>(
            get: { nav.selectedTab },
            set: { newTab in
                if newTab == nav.selectedTab && newTab == .search {
                    nav.searchBarFocusRequested = true
                }
                nav.selectedTab = newTab
            }
        )
        ZStack(alignment: .bottom) {
            TabView(selection: tabBinding) {
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
            .onScrollDetected { scrolling in
                nav.isScrolling = scrolling
            }

            if showMiniPlayer {
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
                    .opacity(nav.isScrolling ? 0.3 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: nav.isScrolling)
            }
        }
        .enableInjection()
    }
}
