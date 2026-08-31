import Foundation

/// プレイヤー状態の永続化境界。具体実装と、シャッフル/リピートの既定値
/// (再生フレームワークの raw value)はアプリ側(Infrastructure)に残す
public protocol PlayerStateRepositoryPort {
    func save(
        queueIDs: [String],
        currentIndex: Int,
        playbackRate: Double,
        shuffleModeRaw: Int,
        repeatModeRaw: Int,
        isAutoPlayEnabled: Bool
    ) throws

    // 既存 PlayerStateRepository の公開シグネチャをそのまま port にした結果のタプル
    // swiftlint:disable:next large_tuple
    func load() throws -> (
        queueIDs: [String],
        currentIndex: Int,
        playbackRate: Double,
        shuffleModeRaw: Int,
        repeatModeRaw: Int,
        isAutoPlayEnabled: Bool
    )
}
