import Foundation
import SwiftUI
import MusicKit
import Observation
import NightCoreDomain

@Observable
@MainActor
final class PlaylistViewModel {

    var rows: [PlaylistRowModel] = []
    var isLoading = false
    var errorMessage: String?

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
            rows = playlists.map { pl in
                PlaylistRowModel(
                    id: pl.id,
                    title: pl.name,
                    artwork: pl.artwork,
                    playlist: pl
                )
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            rows = []
        }
    }
}
