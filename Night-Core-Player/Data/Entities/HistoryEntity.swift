import Foundation
import SwiftData

@Model
final class HistoryEntity {
    @Attribute(.unique) var id: String = UUID().uuidString

    var songID: String

    var playedAt: Date

    init(songID: String, playedAt: Date = .now) {
        self.songID   = songID
        self.playedAt = playedAt
    }
}
