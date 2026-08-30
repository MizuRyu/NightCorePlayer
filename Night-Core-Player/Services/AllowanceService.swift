import Foundation

// MARK: - Protocol

@MainActor
protocol AllowanceService: Sendable {
    func entitlement(now: Date) throws -> PlaybackEntitlement
    func consume(_ seconds: TimeInterval, now: Date) throws
    func grantReward(now: Date) throws -> TimeInterval
    /// 今日あと何回リワードを受け取れるか。日次リセットで上限まで戻る
    func rewardsRemainingToday(now: Date) throws -> Int
    func shouldShowProPrompt(now: Date) throws -> Bool
    func markProPromptShown(now: Date) throws

    #if DEBUG
        /// 検証用: トライアルを終了させ残高を使い切った状態にする。リワード広告と枯渇シートの実機確認に使う
        func debugExhaust(now: Date) throws
        /// 検証用: 残高の記録を消し、初回起動前の状態に戻す
        func debugReset() throws
    #endif
}

// MARK: - Impl

@MainActor
final class AllowanceServiceImpl: AllowanceService {
    private static let daySeconds: TimeInterval = 86400

    /// 実時刻が初回起動より1時間以上過去なら時計改竄とみなす許容幅
    private static let trialClockToleranceSeconds: TimeInterval = 3600

    private let repo: AllowanceRepository

    init(repo: AllowanceRepository) {
        self.repo = repo
    }

    func entitlement(now: Date) throws -> PlaybackEntitlement {
        let snapshot = try normalizedSnapshot(now: now)
        if isTrialActive(snapshot: snapshot, now: now) {
            return .trial(endsAt: trialEndDate(firstLaunchAt: snapshot.firstLaunchAt))
        }
        return snapshot.remainingSeconds > 0
            ? .free(remaining: snapshot.remainingSeconds)
            : .exhausted
    }

    func consume(_ seconds: TimeInterval, now: Date) throws {
        var snapshot = try normalizedSnapshot(now: now)
        guard !isTrialActive(snapshot: snapshot, now: now) else { return }
        snapshot.remainingSeconds = max(0, snapshot.remainingSeconds - max(0, seconds))
        try repo.save(snapshot)
    }

    func grantReward(now: Date) throws -> TimeInterval {
        var snapshot = try normalizedSnapshot(now: now)
        // UI側でボタンを無効化しているが、時刻またぎ等での重複付与をここでも止める
        guard snapshot.rewardCountToday < Constants.Allowance.dailyRewardLimit else {
            throw AppError.player(String(localized: "You've reached today's ad limit. It resets tomorrow."))
        }
        snapshot.remainingSeconds += Constants.Allowance.rewardSeconds
        snapshot.rewardCountTotal += 1
        snapshot.rewardCountToday += 1
        try repo.save(snapshot)
        return snapshot.remainingSeconds
    }

    func rewardsRemainingToday(now: Date) throws -> Int {
        let snapshot = try normalizedSnapshot(now: now)
        return max(0, Constants.Allowance.dailyRewardLimit - snapshot.rewardCountToday)
    }

    func shouldShowProPrompt(now: Date) throws -> Bool {
        let snapshot = try normalizedSnapshot(now: now)
        return snapshot.rewardCountTotal >= Constants.Allowance.proPromptRewardCount
            && !snapshot.proPromptShown
    }

    func markProPromptShown(now: Date) throws {
        var snapshot = try normalizedSnapshot(now: now)
        snapshot.proPromptShown = true
        try repo.save(snapshot)
    }

    #if DEBUG
        func debugExhaust(now: Date) throws {
            var snapshot = try normalizedSnapshot(now: now)
            // トライアル判定を抜けるため初回起動をトライアル期間より前に倒す
            snapshot.firstLaunchAt = now.addingTimeInterval(
                -TimeInterval(Constants.Allowance.trialDays + 1) * Self.daySeconds
            )
            snapshot.remainingSeconds = 0
            // normalizedSnapshot の日次リセットで残高が戻らないよう次回リセットを先送りする
            snapshot.nextResetAt = now.addingTimeInterval(Self.daySeconds)
            snapshot.lastSeenAt = now
            try repo.save(snapshot)
        }

        func debugReset() throws {
            try repo.reset()
        }
    #endif

    // MARK: - Private

    /// 時計を過去に戻しても lastSeenAt より前には進まない
    private func guardedNow(_ now: Date, snapshot: AllowanceSnapshot) -> Date {
        max(now, snapshot.lastSeenAt)
    }

    private func normalizedSnapshot(now: Date) throws -> AllowanceSnapshot {
        var snapshot = try repo.loadOrCreate(now: now)
        let guarded = guardedNow(now, snapshot: snapshot)
        snapshot.lastSeenAt = guarded
        if guarded >= snapshot.nextResetAt {
            snapshot.remainingSeconds = Constants.Allowance.dailyFreeSeconds
            snapshot.rewardCountToday = 0
            snapshot.nextResetAt = guarded.addingTimeInterval(Self.daySeconds)
            try repo.save(snapshot)
        }
        return snapshot
    }

    private func isTrialActive(snapshot: AllowanceSnapshot, now: Date) -> Bool {
        guard now >= snapshot.firstLaunchAt - Self.trialClockToleranceSeconds else { return false }
        return guardedNow(now, snapshot: snapshot) < trialEndDate(firstLaunchAt: snapshot.firstLaunchAt)
    }

    private func trialEndDate(firstLaunchAt: Date) -> Date {
        firstLaunchAt.addingTimeInterval(TimeInterval(Constants.Allowance.trialDays) * Self.daySeconds)
    }
}
