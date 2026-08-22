import Foundation
import Observation
import MusicKit

@Observable
final class PlayerNavigator {
    enum Tab: Hashable, CaseIterable {
        case player, search, playlist, settings
    }

    var selectedTab: Tab = .player
    var songs: [Song] = []
    var initialIndex: Int = 0

    var searchBarFocusRequestID: Int = 0
    var pendingArtist: Artist?
    var isScrolling: Bool = false
}
