import Foundation

// MARK: - Protocol

/// 再生速度のデフォルト値を管理する（Preference コンテキスト）
/// - Session Rate（一時的）は MusicPlayerService が管理
/// - Default Rate（永続化）は本プロトコルが管理
@MainActor
protocol PlaybackRateManager: Sendable {
    /// 永続化されたデフォルト再生速度
    var defaultRate: Double { get }
    /// デフォルト再生速度を更新し、永続化する
    func setDefaultRate(_ rate: Double) throws
}

// MARK: - Impl

@MainActor
final class PlaybackRateManagerImpl: PlaybackRateManager {
    private let repo: PlayerStateRepository
    private(set) var defaultRate: Double

    init(repo: PlayerStateRepository) {
        self.repo = repo
        self.defaultRate = (try? repo.load().playbackRate)
            ?? Constants.MusicPlayer.defaultPlaybackRate
    }

    func setDefaultRate(_ rate: Double) throws {
        let clamped = min(
            max(rate, Constants.MusicPlayer.minPlaybackRate),
            Constants.MusicPlayer.maxPlaybackRate
        )
        defaultRate = clamped

        let current = try repo.load()
        try repo.save(
            queueIDs: current.queueIDs,
            currentIndex: current.currentIndex,
            playbackRate: clamped,
            shuffleModeRaw: current.shuffleModeRaw,
            repeatModeRaw: current.repeatModeRaw
        )
    }
}
