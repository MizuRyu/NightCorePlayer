import SwiftUI
import Inject
import MusicKit

struct MainTabView: View {
    @ObserveInjection var inject
    @StateObject private var nav = PlayerNavigator()
    
    var body: some View {
        TabView(selection: $nav.selectedTab) {
            MusicPlayerView()
                .environmentObject(nav)
                .tabItem {
                    Label("Player", systemImage: "music.note")
                }
                .tag(PlayerNavigator.Tab.player)
            
            SearchView()
                .environmentObject(nav)
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(PlayerNavigator.Tab.search)
            
            PlaylistView()
                .environmentObject(nav)
                .tabItem {
                    Label("Playlist", systemImage: "list.bullet")
                }
                .tag(PlayerNavigator.Tab.playlist)
            
            SettingsView()
                .environmentObject(nav)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(PlayerNavigator.Tab.settings)
        }
        .enableInjection()
    }
}
