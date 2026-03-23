import Foundation
import SwiftUI
import MusicKit
import Observation

@Observable
@MainActor
final class PlaylistViewModel {
    
    var playlists: [Playlist] = []
    var rows: [PlaylistRowModel] = []
    var isLoading = false
    var errorMessage: String?
    
    private var artworkCache: [MusicItemID: UIImage] = [:]
    private let musicKitService: MusicKitService
    
    init(musicKitService: MusicKitService) {
        self.musicKitService = musicKitService
    }
    
    func load(limit: Int = Constants.MusicAPI.playlistsLoadLimit) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        
        do {
            let playlists = try await musicKitService.fetchLibraryPlaylists(limit: limit)
            self.rows = playlists.map { pl in
                PlaylistRowModel(
                    id: pl.id,
                    title: pl.name,
                    artwork: pl.artwork,
                    playlist: pl
                )
            }
            errorMessage = nil
            
            await withTaskGroup(of: Void.self) { group in
                for pl in playlists {
                    group.addTask { [weak self] in
                        await self?.fetchArtwork(for: pl)}
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            playlists = []
        }
    }
    
    // MARK: - Artwork 取得
    private func fetchArtwork(for playlist: Playlist) async {
        guard let url = playlist.artwork?.url(width: 100, height: 100) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let uiImage = UIImage(data: data) else { return }
            
            artworkCache[playlist.id] = uiImage
            
            if let idx = rows.firstIndex(where: { $0.id == playlist.id }) {
                rows[idx] = PlaylistRowModel(
                    id: rows[idx].id,
                    title: rows[idx].title,
                    artwork: rows[idx].artwork,
                    playlist: rows[idx].playlist
                )
            }
            
        } catch {
        }
    }
}
