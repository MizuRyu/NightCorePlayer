import Foundation
import NightCoreDomain

// MARK: - Allowance 連携（残高消費 tick に対する再生側の反応）

extension MusicPlayerServiceImpl {
    public func resumeAfterRewardGrant() async {
        guard let savedRate = rateBeforeAllowanceStop else { return }
        rateBeforeAllowanceStop = nil
        // ユーザーが既に手動で再生を再開していたら、倍速だけ勝手に変えない
        guard player.playbackState != .playing else { return }
        currentPlaybackRate = savedRate
        await play()
    }

    /// 猶予を使い切った後の曲で倍速に入られた場合、曲末を待たず等速へ戻す。
    /// 曲末停止は「残高が尽きた時点で鳴っていた曲」だけの猶予であり、別の曲には及ばない
    func revertToNormalRateIfNeeded() {
        guard let enforcer = allowanceEnforcer, enforcer.shouldRevertToNormalRateNow() else { return }
        rateBeforeAllowanceStop = currentPlaybackRate
        currentPlaybackRate = Constants.MusicPlayer.normalPlaybackRate
        player.playbackRate = currentPlaybackRate
        enforcer.markRevertedToNormalRate()
    }

    /// 枯渇時は曲境界でのみ停止する。素の（等速）再生は制限しない
    func stopAtSongBoundaryIfNeeded(pausePlayer: Bool) -> Bool {
        guard let enforcer = allowanceEnforcer, enforcer.shouldStopAtSongBoundary() else { return false }
        if pausePlayer {
            player.pause()
        }
        rateBeforeAllowanceStop = currentPlaybackRate
        currentPlaybackRate = Constants.MusicPlayer.normalPlaybackRate
        player.playbackRate = currentPlaybackRate
        enforcer.markStoppedAtSongEnd()
        return true
    }
}
