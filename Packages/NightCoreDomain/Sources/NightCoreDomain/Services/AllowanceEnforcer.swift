import Foundation
import Combine
import os

// Playback: 再生パイプライン内で残高消費と枯渇時の曲境界停止を担う

// MARK: - Event

public enum AllowanceEvent: Sendable {
    case exhaustedPendingSongEnd
    case stoppedAtSongEnd
    /// 残高がないまま倍速へ変更したため等速へ戻した。無言で速度が戻ると理由が伝わらない
    case revertedToNormalRate
}

// MARK: - Protocol

@MainActor
public protocol AllowanceEnforcer: Sendable {
    var events: AnyPublisher<AllowanceEvent, Never> { get }
    var isExhausted: Bool { get }
    func tick(isPlaying: Bool, rate: Double, songID: String?, playbackPosition: TimeInterval?, now: Date)
    func shouldStopAtSongBoundary() -> Bool
    /// 猶予対象外の曲で倍速再生が始まった場合に true。曲末を待たず等速へ戻す
    func shouldRevertToNormalRateNow() -> Bool
    func markStoppedAtSongEnd()
    func markRevertedToNormalRate()
}

// MARK: - Impl

@MainActor
public final class AllowanceEnforcerImpl: AllowanceEnforcer {
    private let logger = Logger(subsystem: Constants.Logging.subsystem, category: "Allowance")

    private let allowanceService: AllowanceService

    /// Pro購入者は残高消費・枯渇停止の対象外。App.swiftでProStoreServiceに接続される
    private let isProEntitled: () -> Bool

    private let eventSubject = PassthroughSubject<AllowanceEvent, Never>()
    public var events: AnyPublisher<AllowanceEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    private var lastTickAt: Date?

    /// 前回tick時点の再生位置と、その位置が属していた曲。消費量を wall-clock ではなく
    /// 実際に進んだ再生位置から求めるための基準（tickが欠落しても実再生ぶんだけ消費する）
    private var lastPlaybackPosition: TimeInterval?
    private var lastPositionSongID: String?

    /// entitlement == .exhausted の写し。残高そのものの状態を表し、停止予約とは独立している
    private var isBalanceExhausted = false

    /// 曲末までの猶予を与えた曲のID。ADR-003の猶予は「残高が尽きた時点で鳴っていた曲」だけが対象で、
    /// 別の曲に移った時点で猶予は終わる。Bool だけで持つと倍速/等速の切替で猶予を取り直せてしまう
    private var graceSongID: String?

    /// 枯渇後に猶予を1曲ぶん使ったか。残高が回復するまで再取得させない
    private var hasUsedGrace = false

    /// 猶予対象外の曲で倍速を検知した。曲末を待たず等速へ戻す
    private var needsRevertToNormalRate = false

    /// 直前の tick で「残高があり倍速で再生中」だったか。
    /// 曲末までの猶予は、この状態から残高が尽きた場合にだけ与える
    private var wasSpedUpBeforeExhaustion = false

    /// 残高を一度でも観測したか。初回 tick は isBalanceExhausted が初期値のままで
    /// 「残高があった」と誤認してしまうため、観測前は猶予を与えない
    private var hasObservedBalance = false

    public init(
        allowanceService: AllowanceService,
        isProEntitled: @escaping () -> Bool = { false }
    ) {
        self.allowanceService = allowanceService
        self.isProEntitled = isProEntitled
    }

    public var isExhausted: Bool { isBalanceExhausted }

    public func tick(isPlaying: Bool, rate: Double, songID: String?, playbackPosition: TimeInterval?, now: Date) {
        // Proは消費もアームもしない。既存の停止予約があれば解除して即return
        guard !isProEntitled() else {
            // lastTickAtを進めないとPro期間ぶんが溜まり、Pro解除後の初回tickで一括消費される
            lastTickAt = now
            recordPosition(playbackPosition, songID: songID)
            isBalanceExhausted = false
            clearGrace()
            return
        }

        let baseline = lastTickAt ?? now
        lastTickAt = now

        // consume する前の状態を控える。「残高があるうちから倍速で鳴っていた」ことが
        // 曲末までの猶予を与える条件になる
        let isSpedUpNow = isPlaying && rate != Constants.MusicPlayer.normalPlaybackRate
        let hadBalanceBeforeConsume = hasObservedBalance && !isBalanceExhausted

        // 等速再生・素の再生は消費しない。トライアル中かはAllowanceService内部で判定される
        if isPlaying, rate != Constants.MusicPlayer.normalPlaybackRate {
            let consumable = consumableSeconds(
                wallDelta: max(0, now.timeIntervalSince(baseline)),
                rate: rate,
                songID: songID,
                playbackPosition: playbackPosition
            )
            if consumable > 0 {
                do {
                    try allowanceService.consume(consumable, now: now)
                } catch {
                    logger.error("Allowance consume error: \(error.localizedDescription)")
                }
            }
        }

        // 消費しないtick（等速・停止中）でも基準は進める。進めないと、次に倍速へ入ったtickで
        // 等速再生ぶんの位置差まで消費対象に含まれてしまう
        recordPosition(playbackPosition, songID: songID)

        // 残高状態の写しを更新。consume後に判定することで、残高が尽きたtick内で以降の分岐に反映できる
        if let entitlement = try? allowanceService.entitlement(now: now) {
            if case .exhausted = entitlement {
                isBalanceExhausted = true
            } else {
                isBalanceExhausted = false
                // クリア条件: 残高が戻れば猶予の使用履歴ごと解除し、次の枯渇でまた1曲ぶん与える
                clearGrace()
                hasUsedGrace = false
            }
        }

        // 残高があるうちから倍速で鳴っていたか。この tick で尽きた場合だけ曲末までの猶予を与える
        wasSpedUpBeforeExhaustion = isSpedUpNow && hadBalanceBeforeConsume
        hasObservedBalance = true

        // 等速再生は残高に関係なく一切止めない。ただし猶予の紐付けは保持する
        // （倍速→等速→倍速で猶予を取り直せてしまうため）
        guard isPlaying, rate != Constants.MusicPlayer.normalPlaybackRate else { return }
        guard isBalanceExhausted else { return }

        // 猶予が有効な間は何もしない。別の曲へ移った場合の停止は曲境界停止が担当する
        guard graceSongID == nil else { return }

        // 曲末までの猶予は「倍速で再生している最中に残高が尽きた」場合だけに与える。
        // ADR-003 が避けたいのは鳴っている音楽が途中で切れることであり、
        // 残高0の状態から倍速へ入れる操作まで許すと1曲まるごと無料で聴けてしまう。
        guard wasSpedUpBeforeExhaustion, !hasUsedGrace else {
            needsRevertToNormalRate = true
            return
        }

        graceSongID = songID
        hasUsedGrace = true
        eventSubject.send(.exhaustedPendingSongEnd)
    }

    public func shouldStopAtSongBoundary() -> Bool {
        // tickを経由せず曲境界判定が走っても、Proユーザーを止めない
        !isProEntitled() && graceSongID != nil
    }

    public func shouldRevertToNormalRateNow() -> Bool {
        !isProEntitled() && needsRevertToNormalRate
    }

    public func markStoppedAtSongEnd() {
        guard graceSongID != nil else { return }
        graceSongID = nil
        eventSubject.send(.stoppedAtSongEnd)
    }

    public func markRevertedToNormalRate() {
        guard needsRevertToNormalRate else { return }
        needsRevertToNormalRate = false
        eventSubject.send(.revertedToNormalRate)
    }

    // MARK: - Private

    /// 実際に進んだ再生位置から消費秒数を求める。倍速で position が x 秒進めば、
    /// 費やした実時間は x / rate 秒。wallDelta を上限に置くのは前方シークで過大請求しないため
    private func consumableSeconds(
        wallDelta: TimeInterval,
        rate: Double,
        songID: String?,
        playbackPosition: TimeInterval?
    ) -> TimeInterval {
        guard
            songID == lastPositionSongID,
            let previous = lastPlaybackPosition,
            let current = playbackPosition
        else {
            // 曲間や位置取得不能時のフォールバック。位置で検算できないぶんは wall-clock で消費する
            return wallDelta
        }
        // 後方シークは positionDelta が負になる。その tick は消費しない
        return min(wallDelta, max(0, current - previous) / max(rate, 1.0))
    }

    private func recordPosition(_ playbackPosition: TimeInterval?, songID: String?) {
        lastPlaybackPosition = playbackPosition
        lastPositionSongID = songID
    }

    private func clearGrace() {
        graceSongID = nil
        needsRevertToNormalRate = false
    }
}
