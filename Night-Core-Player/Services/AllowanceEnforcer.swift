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
    func tick(isPlaying: Bool, rate: Double, now: Date)
    func shouldStopAtSongBoundary() -> Bool
    func markStoppedAtSongEnd()
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

    /// 曲境界での停止予約。「枯滅+再生中+倍速」を観測したときだけアームされる
    private var pendingStopAtSongEnd = false

    init(
        allowanceService: AllowanceService,
        isProEntitled: @escaping () -> Bool = { false }
    ) {
        self.allowanceService = allowanceService
        self.isProEntitled = isProEntitled
    }

    var isExhausted: Bool { isBalanceExhausted }

    func tick(isPlaying: Bool, rate: Double, now: Date) {
        // Proは消費もアームもしない。既存の停止予約があれば解除して即return
        guard !isProEntitled() else {
            // lastTickAtを進めないとPro期間ぶんが溜まり、Pro解除後の初回tickで一括消費される
            lastTickAt = now
            isBalanceExhausted = false
            pendingStopAtSongEnd = false
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
                // クリア条件: 残高回復時は曲境界での停止予約も解除する
                pendingStopAtSongEnd = false
            }
        }

        // クリア条件: 等速再生を観測したら停止予約を解除する。
        // 素のApple Music再生（等速）は残高に関係なく一切止めないため
        if isPlaying, rate == Constants.MusicPlayer.normalPlaybackRate {
            pendingStopAtSongEnd = false
            return
        }

        // アーム条件: 「枯滅+再生中+倍速」のときだけ。false→true遷移時に一度だけイベントを出す。
        // 枯滅しているだけでは絶対にアームしない
        if isBalanceExhausted, isPlaying, !pendingStopAtSongEnd {
            pendingStopAtSongEnd = true
            eventSubject.send(.exhaustedPendingSongEnd)
        }
    }

    func shouldStopAtSongBoundary() -> Bool {
        // tickを経由せず曲境界判定が走っても、Proユーザーを止めない
        !isProEntitled() && pendingStopAtSongEnd
    }

    func markStoppedAtSongEnd() {
        guard pendingStopAtSongEnd else { return }
        pendingStopAtSongEnd = false
        eventSubject.send(.stoppedAtSongEnd)
    }
}
