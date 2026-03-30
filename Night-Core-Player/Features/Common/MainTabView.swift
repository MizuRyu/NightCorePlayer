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
                    nav.searchBarFocusRequestID += 1
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
            .overlay(alignment: .bottom) {
                // 検索タブ位置にオーバーレイしてタップ/長押しを検出
                GeometryReader { geo in
                    let tabs = PlayerNavigator.Tab.allCases
                    let tabCount = max(1, CGFloat(tabs.count))
                    let tabWidth = geo.size.width / tabCount
                    let searchIndex = CGFloat(tabs.firstIndex(of: .search) ?? 1)
                    Color.clear
                        .frame(width: tabWidth, height: 50)
                        .contentShape(Rectangle())
                        .position(x: tabWidth * (searchIndex + 0.5), y: geo.size.height - 25)
                        .onTapGesture {
                            if nav.selectedTab == .search {
                                nav.searchBarFocusRequestID += 1
                            } else {
                                nav.selectedTab = .search
                            }
                        }
                        .onLongPressGesture(minimumDuration: 0.5) {
                            nav.selectedTab = .search
                            nav.searchBarFocusRequestID += 1
                        }
                }
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
