import Foundation
import SwiftUI
import MusicKit

struct PlaylistRowModel: Identifiable {
    let id: Playlist.ID
    let title: String
    let artwork: Artwork?
    let playlist: Playlist
}

extension PlaylistRowModel: Hashable {
    static func == (lhs: PlaylistRowModel, rhs: PlaylistRowModel) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
