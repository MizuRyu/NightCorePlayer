import Foundation
import Observation
import MusicKit

@Observable
final class PlayerNavigator {
    enum Tab: Hashable {
        case player, search, playlist, settings
    }
    
    var selectedTab: Tab = .player
    var songs: [Song] = []
    var initialIndex: Int = 0
}
