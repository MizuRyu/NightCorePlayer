import Foundation

// MARK: - Protocol

@MainActor
protocol AllowanceService: Sendable {
    func entitlement(now: Date) throws -> PlaybackEntitlement
    func consume(_ seconds: TimeInterval, now: Date) throws
    func grantReward(now: Date) throws -> TimeInterval
    func shouldShowProPrompt(now: Date) throws -> Bool
    func markProPromptShown(now: Date) throws
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
        snapshot.remainingSeconds += Constants.Allowance.rewardSeconds
        snapshot.rewardCountTotal += 1
        try repo.save(snapshot)
        return snapshot.remainingSeconds
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
