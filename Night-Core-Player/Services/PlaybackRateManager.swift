import Foundation

// MARK: - Protocol

@MainActor
protocol PlaybackRateManager: Sendable {
    var defaultRate: Double { get }
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
            repeatModeRaw: current.repeatModeRaw,
            isAutoPlayEnabled: current.isAutoPlayEnabled
        )
    }
}
