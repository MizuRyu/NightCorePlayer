import Foundation
import SwiftUI
import MusicKit

struct PlaylistRowModel: Identifiable, Hashable {
    let id: Playlist.ID
    let title: String
    let artwork: Artwork?
    let playlist: Playlist
}
