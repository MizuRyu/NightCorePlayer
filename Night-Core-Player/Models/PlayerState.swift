import Foundation

struct PlayerState {
    let queueIDs: [String]
    let currentIndex: Int
    let playbackRate: Double
    let shuffleModeRaw: Int
    let repeatModeRaw: Int
}
