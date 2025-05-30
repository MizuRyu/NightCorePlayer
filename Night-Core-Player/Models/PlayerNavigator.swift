import Foundation
import MusicKit

final class PlayerNavigator: ObservableObject {
    enum Tab: Hashable {
        case player, search, playlist, settings
    }
    
    @Published var selectedTab: Tab = .search
    @Published var songs: [Song] = []
    @Published var initialIndex: Int = 0
}
