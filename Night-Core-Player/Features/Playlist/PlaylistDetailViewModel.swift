import Foundation
import MusicKit
import Observation

@Observable
@MainActor
final class PlaylistDetailViewModel {
    let playlist: Playlist
    private(set) var songs: [Song] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    
    private var musicKitService: MusicKitService
    
    init(playlist: Playlist,
         musicKitService: MusicKitService) {
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
