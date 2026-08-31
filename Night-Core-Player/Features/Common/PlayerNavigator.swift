import Foundation
import MusicKit
import Observation

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

    /// 再生キューシートの表示状態。AllowanceSheetの提示と排他にするためNavigatorで共有する
    var isQueuePresented: Bool = false
}
