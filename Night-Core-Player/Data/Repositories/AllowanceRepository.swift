import Foundation
import SwiftData

final class AllowanceRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func loadOrCreate(now: Date, dayKey: String) throws -> AllowanceSnapshot {
        if let e = try fetch() {
            return AllowanceSnapshot(
                firstLaunchAt: e.firstLaunchAt,
                lastResetDayKey: e.lastResetDayKey,
                remainingSeconds: e.remainingSeconds,
                lastSeenAt: e.lastSeenAt,
                rewardCountTotal: e.rewardCountTotal,
                proPromptShown: e.proPromptShown
            )
        }
        let entity = AllowanceEntity(
            firstLaunchAt: now,
            lastResetDayKey: dayKey,
            lastSeenAt: now
        )
        context.insert(entity)
        try context.save()
        return AllowanceSnapshot(
            firstLaunchAt: entity.firstLaunchAt,
            lastResetDayKey: entity.lastResetDayKey,
            remainingSeconds: entity.remainingSeconds,
            lastSeenAt: entity.lastSeenAt,
            rewardCountTotal: entity.rewardCountTotal,
            proPromptShown: entity.proPromptShown
        )
    }

    func save(_ snapshot: AllowanceSnapshot) throws {
        guard let e = try fetch() else {
            let entity = AllowanceEntity(
                firstLaunchAt: snapshot.firstLaunchAt,
                lastResetDayKey: snapshot.lastResetDayKey,
                remainingSeconds: snapshot.remainingSeconds,
                lastSeenAt: snapshot.lastSeenAt,
                rewardCountTotal: snapshot.rewardCountTotal,
                proPromptShown: snapshot.proPromptShown
            )
            context.insert(entity)
            try context.save()
            return
        }
        e.firstLaunchAt = snapshot.firstLaunchAt
        e.lastResetDayKey = snapshot.lastResetDayKey
        e.remainingSeconds = snapshot.remainingSeconds
        e.lastSeenAt = snapshot.lastSeenAt
        e.rewardCountTotal = snapshot.rewardCountTotal
        e.proPromptShown = snapshot.proPromptShown
        try context.save()
    }

    func reset() throws {
        if let e = try fetch() {
            context.delete(e)
            try context.save()
        }
    }

    private func fetch() throws -> AllowanceEntity? {
        let descriptor = FetchDescriptor<AllowanceEntity>(
            predicate: #Predicate { $0.id == "default" }
        )
        return try context.fetch(descriptor).first
    }
}
