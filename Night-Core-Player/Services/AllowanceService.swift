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
    private let repo: AllowanceRepository
    private let calendar: Calendar

    init(repo: AllowanceRepository, calendar: Calendar = .current) {
        self.repo = repo
        self.calendar = calendar
    }

    func entitlement(now: Date) throws -> PlaybackEntitlement {
        let snapshot = try normalizedSnapshot(now: now)
        let trialEnd = trialEndDate(firstLaunchAt: snapshot.firstLaunchAt)
        if guardedNow(now, snapshot: snapshot) < trialEnd {
            return .trial(endsAt: trialEnd)
        }
        return snapshot.remainingSeconds > 0
            ? .free(remaining: snapshot.remainingSeconds)
            : .exhausted
    }

    func consume(_ seconds: TimeInterval, now: Date) throws {
        var snapshot = try normalizedSnapshot(now: now)
        let trialEnd = trialEndDate(firstLaunchAt: snapshot.firstLaunchAt)
        guard guardedNow(now, snapshot: snapshot) >= trialEnd else { return }
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
        var snapshot = try repo.loadOrCreate(now: now, dayKey: dayKey(for: now))
        let guarded = guardedNow(now, snapshot: snapshot)
        let key = dayKey(for: guarded)
        if key != snapshot.lastResetDayKey {
            snapshot.lastResetDayKey = key
            snapshot.remainingSeconds = Constants.Allowance.dailyFreeSeconds
        }
        snapshot.lastSeenAt = guarded
        try repo.save(snapshot)
        return snapshot
    }

    private func trialEndDate(firstLaunchAt: Date) -> Date {
        calendar.date(
            byAdding: .day,
            value: Constants.Allowance.trialDays,
            to: firstLaunchAt
        ) ?? firstLaunchAt
    }

    private func dayKey(for date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
