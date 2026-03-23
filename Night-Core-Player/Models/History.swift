import Foundation

/// 再生履歴のドメインモデル（純粋 struct。SwiftData 依存なし）
struct History {
    let id: String
    let songID: String
    let playedAt: Date
}
