import Foundation
import NightCoreDomain

/// SwiftData 実装 (PlayerStateRepository) の永続化挙動をタプル1本で模す。
/// 未保存時の既定値もアプリ実装に合わせる
final class InMemoryPlayerStateRepository: PlayerStateRepositoryPort {
    /// MPMusicShuffleMode.off / MPMusicRepeatMode.none の rawValue (どちらも 1。0 は default)
    private static let shuffleOffRaw = 1
    private static let repeatNoneRaw = 1

    // swiftlint:disable:next large_tuple
    private var stored: (
        queueIDs: [String],
        currentIndex: Int,
        playbackRate: Double,
        shuffleModeRaw: Int,
        repeatModeRaw: Int,
        isAutoPlayEnabled: Bool
    )?

    func save(
        queueIDs: [String],
        currentIndex: Int,
        playbackRate: Double,
        shuffleModeRaw: Int,
        repeatModeRaw: Int,
        isAutoPlayEnabled: Bool
    ) throws {
        stored = (queueIDs, currentIndex, playbackRate, shuffleModeRaw, repeatModeRaw, isAutoPlayEnabled)
    }

    // swiftlint:disable:next large_tuple
    func load() throws -> (
        queueIDs: [String],
        currentIndex: Int,
        playbackRate: Double,
        shuffleModeRaw: Int,
        repeatModeRaw: Int,
        isAutoPlayEnabled: Bool
    ) {
        stored ?? (
            [], 0,
            Constants.MusicPlayer.defaultPlaybackRate,
            Self.shuffleOffRaw,
            Self.repeatNoneRaw,
            false
        )
    }
}
