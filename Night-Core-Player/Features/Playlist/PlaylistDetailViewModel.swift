import Foundation
import MusicKit

@MainActor
class PlaylistDetailViewModel: ObservableObject {
    let playlist: Playlist
    @Published var tracks: [Track] = []
    @Published private(set) var songs: [Song] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    
    private var musicKitService: MusicKitService
    
    init(playlist: Playlist,
         musicKitService: MusicKitService = MusicKitServiceImpl()) {
        self.playlist = playlist
        self.musicKitService = musicKitService
    }
    
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        
        do {
            songs = try await musicKitService.fetchPlaylistSongs(in: playlist)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            songs = []
        }
    }
}
