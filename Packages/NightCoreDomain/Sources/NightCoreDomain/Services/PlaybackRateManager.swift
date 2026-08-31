import Foundation

// MARK: - Protocol

@MainActor
public protocol PlaybackRateManager: Sendable {
    var defaultRate: Double { get }
    func setDefaultRate(_ rate: Double) throws
}

// MARK: - Impl

@MainActor
public final class PlaybackRateManagerImpl: PlaybackRateManager {
    private let repo: PlayerStateRepositoryPort
    public private(set) var defaultRate: Double

    public init(repo: PlayerStateRepositoryPort) {
        self.repo = repo
        self.defaultRate = (try? repo.load().playbackRate)
            ?? Constants.MusicPlayer.defaultPlaybackRate
    }

    public func setDefaultRate(_ rate: Double) throws {
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
