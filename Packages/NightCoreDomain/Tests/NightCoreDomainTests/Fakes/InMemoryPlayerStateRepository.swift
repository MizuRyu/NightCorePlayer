import Foundation
import NightCoreDomain
import NightCoreDomainTestSupport

/// SwiftData 実装 (PlayerStateRepository) の永続化挙動をタプル1本で模す。
/// 未保存時の既定値もアプリ実装に合わせる。
/// 「別インスタンスから読み直しても復元される」テスト前提は、
/// 同じ store を共有する別インスタンスを渡すことで保つ
final class InMemoryPlayerStateRepository: PlayerStateRepositoryPort {
    /// MPMusicShuffleMode.off / MPMusicRepeatMode.none の rawValue (どちらも 1。0 は default)
    private static let shuffleOffRaw = 1
    private static let repeatNoneRaw = 1

    private let store: InMemoryPlayerStateStore

    init(store: InMemoryPlayerStateStore = InMemoryPlayerStateStore()) {
        self.store = store
    }

    func save(
        queueIDs: [String],
        currentIndex: Int,
        playbackRate: Double,
        shuffleModeRaw: Int,
        repeatModeRaw: Int,
        isAutoPlayEnabled: Bool
    ) throws {
        store.state = (queueIDs, currentIndex, playbackRate, shuffleModeRaw, repeatModeRaw, isAutoPlayEnabled)
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
        store.state ?? (
            [], 0,
            Constants.MusicPlayer.defaultPlaybackRate,
            Self.shuffleOffRaw,
            Self.repeatNoneRaw,
            false
        )
    }
}
