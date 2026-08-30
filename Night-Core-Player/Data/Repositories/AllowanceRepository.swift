import Foundation
import SwiftData

final class AllowanceRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func loadOrCreate(now: Date) throws -> AllowanceSnapshot {
        if let e = try fetch() {
            return AllowanceSnapshot(
                firstLaunchAt: e.firstLaunchAt,
                nextResetAt: e.nextResetAt,
                remainingSeconds: e.remainingSeconds,
                lastSeenAt: e.lastSeenAt,
                rewardCountTotal: e.rewardCountTotal,
                rewardCountToday: e.rewardCountToday,
                proPromptShown: e.proPromptShown
            )
        }
        let entity = AllowanceEntity(
            firstLaunchAt: now,
            nextResetAt: now.addingTimeInterval(86400),
            lastSeenAt: now
        )
        context.insert(entity)
        try context.save()
        return AllowanceSnapshot(
            firstLaunchAt: entity.firstLaunchAt,
            nextResetAt: entity.nextResetAt,
            remainingSeconds: entity.remainingSeconds,
            lastSeenAt: entity.lastSeenAt,
            rewardCountTotal: entity.rewardCountTotal,
            rewardCountToday: entity.rewardCountToday,
            proPromptShown: entity.proPromptShown
        )
    }

    func save(_ snapshot: AllowanceSnapshot) throws {
        guard let e = try fetch() else {
            let entity = AllowanceEntity(
                firstLaunchAt: snapshot.firstLaunchAt,
                nextResetAt: snapshot.nextResetAt,
                remainingSeconds: snapshot.remainingSeconds,
                lastSeenAt: snapshot.lastSeenAt,
                rewardCountTotal: snapshot.rewardCountTotal,
                rewardCountToday: snapshot.rewardCountToday,
                proPromptShown: snapshot.proPromptShown
            )
            context.insert(entity)
            try context.save()
            return
        }
        e.firstLaunchAt = snapshot.firstLaunchAt
        e.nextResetAt = snapshot.nextResetAt
        e.remainingSeconds = snapshot.remainingSeconds
        e.lastSeenAt = snapshot.lastSeenAt
        e.rewardCountTotal = snapshot.rewardCountTotal
        e.rewardCountToday = snapshot.rewardCountToday
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
