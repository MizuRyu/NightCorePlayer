import SwiftUI
import Inject

struct MainTabView: View {
    @ObserveInjection var inject
    var body: some View {
        TabView {
            MusicPlayerView()
                .tabItem {
                    Label("Player", systemImage: "music.note")
                }
            
            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
            
            PlaylistView()
                .tabItem {
                    Label("Playlist", systemImage: "list.bullet")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .enableInjection()
    }
}
