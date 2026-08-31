import Foundation
import Testing
import NightCoreDomain

/// PlayerStateRepositoryPort の契約検証。fake(InMemoryPlayerStateRepository)と
/// アプリ側の永続化実装(PlayerStateRepository)の両方から同じアサーションを実行するために使う
public enum PlayerStateRepositoryContract {
    /// シャッフルOFF/リピートなしの rawValue (どちらも1。0はdefault)。
    /// Domain は再生フレームワークに依存しないため、既知のraw valueを直接使う
    private static let shuffleOffRaw = 1
    private static let repeatNoneRaw = 1

    /// 未保存時のデフォルト値の検証。fake/実装で shuffle=1, repeat=1 の食い違いが
    /// 起きた事故(Stage A)の再発防止テスト
    public static func verifyLoadDefaults(
        _ make: () throws -> any PlayerStateRepositoryPort
    ) throws {
        let repo = try make()

        let loaded = try repo.load()
        #expect(loaded.queueIDs.isEmpty)
        #expect(loaded.currentIndex == 0)
        #expect(loaded.playbackRate == Constants.MusicPlayer.defaultPlaybackRate)
        #expect(loaded.shuffleModeRaw == shuffleOffRaw)
        #expect(loaded.repeatModeRaw == repeatNoneRaw)
        #expect(loaded.isAutoPlayEnabled == false)
    }

    public static func verifySaveAndLoad(
        _ make: () throws -> any PlayerStateRepositoryPort
    ) throws {
        let repo = try make()

        try repo.save(
            queueIDs: ["id-1", "id-2", "id-3"],
            currentIndex: 1,
            playbackRate: 1.5,
            shuffleModeRaw: 2,
            repeatModeRaw: 3,
            isAutoPlayEnabled: true
        )

        // 別インスタンスから読み直しても永続化された値が返る
        let recreated = try make()
        let loaded = try recreated.load()
        #expect(loaded.queueIDs == ["id-1", "id-2", "id-3"])
        #expect(loaded.currentIndex == 1)
        #expect(loaded.playbackRate == 1.5)
        #expect(loaded.shuffleModeRaw == 2)
        #expect(loaded.repeatModeRaw == 3)
        #expect(loaded.isAutoPlayEnabled == true)
    }
}
