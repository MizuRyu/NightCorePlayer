import Foundation

/// 再生状態のドメインモデル（純粋 struct。SwiftData 依存なし）
struct PlayerState {
    let queueIDs: [String]
    let currentIndex: Int
    let playbackRate: Double
    let shuffleModeRaw: Int
    let repeatModeRaw: Int
}
