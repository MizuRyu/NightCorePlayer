import Foundation
import Combine
import os

// Playback: 再生パイプライン内で残高消費と枯渇時の曲境界停止を担う

// MARK: - Event

enum AllowanceEvent: Sendable {
    case exhaustedPendingSongEnd
    case stoppedAtSongEnd
}

// MARK: - Protocol

@MainActor
protocol AllowanceEnforcer: Sendable {
    var events: AnyPublisher<AllowanceEvent, Never> { get }
    var isExhausted: Bool { get }
    func tick(isPlaying: Bool, rate: Double, songID: String?, now: Date)
    func shouldStopAtSongBoundary() -> Bool
    /// 猶予対象外の曲で倍速再生が始まった場合に true。曲末を待たず等速へ戻す
    func shouldRevertToNormalRateNow() -> Bool
    func markStoppedAtSongEnd()
    func markRevertedToNormalRate()
}

// MARK: - Impl

@MainActor
final class AllowanceEnforcerImpl: AllowanceEnforcer {
    private let logger = Logger(subsystem: Constants.Logging.subsystem, category: "Allowance")
    /// 前回tickからの経過が異常に長い場合のconsume上限（バックグラウンド放置で残高が一気に飛ぶのを防ぐ）
    private static let maxTickIntervalSeconds: TimeInterval = 60

    private let allowanceService: AllowanceService

    /// Pro購入者は残高消費・枯渇停止の対象外。App.swiftでProStoreServiceに接続される
    private let isProEntitled: () -> Bool

    private let eventSubject = PassthroughSubject<AllowanceEvent, Never>()
    var events: AnyPublisher<AllowanceEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    private var lastTickAt: Date?

    /// entitlement == .exhausted の写し。残高そのものの状態を表し、停止予約とは独立している
    private var isBalanceExhausted = false

    /// 曲末までの猶予を与えた曲のID。ADR-003の猶予は「残高が尽きた時点で鳴っていた曲」だけが対象で、
    /// 別の曲に移った時点で猶予は終わる。Bool だけで持つと倍速/等速の切替で猶予を取り直せてしまう
    private var graceSongID: String?

    /// 枯渇後に猶予を1曲ぶん使ったか。残高が回復するまで再取得させない
    private var hasUsedGrace = false

    /// 猶予対象外の曲で倍速を検知した。曲末を待たず等速へ戻す
    private var needsRevertToNormalRate = false

    init(
        allowanceService: AllowanceService,
        isProEntitled: @escaping () -> Bool = { false }
    ) {
        self.allowanceService = allowanceService
        self.isProEntitled = isProEntitled
    }

    var isExhausted: Bool { isBalanceExhausted }

    func tick(isPlaying: Bool, rate: Double, songID: String?, now: Date) {
        // Proは消費もアームもしない。既存の停止予約があれば解除して即return
        guard !isProEntitled() else {
            // lastTickAtを進めないとPro期間ぶんが溜まり、Pro解除後の初回tickで一括消費される
            lastTickAt = now
            isBalanceExhausted = false
            clearGrace()
            return
        }

        let baseline = lastTickAt ?? now
        lastTickAt = now

        // 等速再生・素の再生は消費しない。トライアル中かはAllowanceService内部で判定される
        if isPlaying, rate != Constants.MusicPlayer.normalPlaybackRate {
            let elapsed = min(max(0, now.timeIntervalSince(baseline)), Self.maxTickIntervalSeconds)
            if elapsed > 0 {
                do {
                    try allowanceService.consume(elapsed, now: now)
                } catch {
                    logger.error("Allowance consume error: \(error.localizedDescription)")
                }
            }
        }

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

        // 等速再生は残高に関係なく一切止めない。ただし猶予の紐付けは保持する
        // （倍速→等速→倍速で猶予を取り直せてしまうため）
        guard isPlaying, rate != Constants.MusicPlayer.normalPlaybackRate else { return }
        guard isBalanceExhausted else { return }

        // 猶予が有効な間は何もしない。別の曲へ移った場合の停止は曲境界停止が担当する
        guard graceSongID == nil else { return }

        if hasUsedGrace {
            // 枯渇後の猶予は1曲まで。以降は倍速へ入れさせない
            needsRevertToNormalRate = true
            return
        }

        // アーム条件: 「枯渇+再生中+倍速」を初めて観測した曲だけに曲末までの猶予を与える
        graceSongID = songID
        hasUsedGrace = true
        eventSubject.send(.exhaustedPendingSongEnd)
    }

    func shouldStopAtSongBoundary() -> Bool {
        // tickを経由せず曲境界判定が走っても、Proユーザーを止めない
        !isProEntitled() && graceSongID != nil
    }

    func shouldRevertToNormalRateNow() -> Bool {
        !isProEntitled() && needsRevertToNormalRate
    }

    func markStoppedAtSongEnd() {
        guard graceSongID != nil else { return }
        graceSongID = nil
        eventSubject.send(.stoppedAtSongEnd)
    }

    func markRevertedToNormalRate() {
        guard needsRevertToNormalRate else { return }
        needsRevertToNormalRate = false
        eventSubject.send(.stoppedAtSongEnd)
    }

    // MARK: - Private

    private func clearGrace() {
        graceSongID = nil
        needsRevertToNormalRate = false
    }
}
