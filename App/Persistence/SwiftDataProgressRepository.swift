import Foundation
import StudyCore
import SwiftData

/// Stores the progress in SwiftData. Every `commit` is saved in one transaction: if anything
/// fails the context is rolled back, so a crash or an error never leaves a half-applied action.
@MainActor
final class SwiftDataProgressRepository: ProgressRepository {
    private let context: ModelContext

    init(container: ModelContainer) {
        context = container.mainContext
    }

    // MARK: Reading

    func allProgress() throws -> [String: WordProgress] {
        let rows = try context.fetch(FetchDescriptor<WordProgressEntity>())
        return Dictionary(rows.map { ($0.wordId, $0.value) }, uniquingKeysWith: { _, latest in latest })
    }

    func plan(for day: DayKey) throws -> DailyPlan? {
        try planRow(for: day)?.value
    }

    func allPlans() throws -> [DailyPlan] {
        try context.fetch(FetchDescriptor<DailyPlanEntity>())
            .compactMap(\.value)
            .sorted { $0.dayKey < $1.dayKey }
    }

    func log(on day: DayKey) throws -> [ReviewLogEntry] {
        let key = day.description
        let descriptor = FetchDescriptor<ReviewLogEntity>(
            predicate: #Predicate { $0.dayKey == key }, sortBy: [SortDescriptor(\.at)])
        return try context.fetch(descriptor).compactMap(\.value)
    }

    func allLog() throws -> [ReviewLogEntry] {
        try context.fetch(FetchDescriptor<ReviewLogEntity>(sortBy: [SortDescriptor(\.at)]))
            .compactMap(\.value)
    }

    // MARK: Writing

    func commit(_ change: StateChange) throws {
        do {
            for item in change.progress {
                if let row = try progressRow(for: item.wordId) {
                    row.update(from: item)
                } else {
                    context.insert(WordProgressEntity(item))
                }
            }
            for id in change.removedProgress {
                if let row = try progressRow(for: id) { context.delete(row) }
            }
            if let plan = change.plan {
                if let row = try planRow(for: plan.dayKey) {
                    row.update(from: plan)
                } else {
                    context.insert(DailyPlanEntity(plan))
                }
            }
            for key in change.removedLog {
                if let row = try logRow(for: key) { context.delete(row) }
            }
            for entry in change.appendedLog {
                context.insert(ReviewLogEntity(entry))
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    func eraseAll() throws {
        do {
            try wipe()
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    func replaceAll(progress: [WordProgress], plans: [DailyPlan], log: [ReviewLogEntry]) throws {
        do {
            try wipe()
            for item in progress { context.insert(WordProgressEntity(item)) }
            for plan in plans { context.insert(DailyPlanEntity(plan)) }
            for entry in log { context.insert(ReviewLogEntity(entry)) }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    // MARK: Helpers

    private func wipe() throws {
        try context.delete(model: WordProgressEntity.self)
        try context.delete(model: DailyPlanEntity.self)
        try context.delete(model: ReviewLogEntity.self)
    }

    private func progressRow(for wordId: String) throws -> WordProgressEntity? {
        var descriptor = FetchDescriptor<WordProgressEntity>(predicate: #Predicate { $0.wordId == wordId })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func planRow(for day: DayKey) throws -> DailyPlanEntity? {
        let key = day.description
        var descriptor = FetchDescriptor<DailyPlanEntity>(predicate: #Predicate { $0.dayKey == key })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func logRow(for logKey: LogKey) throws -> ReviewLogEntity? {
        let wordId = logKey.wordId
        let at = logKey.at
        var descriptor = FetchDescriptor<ReviewLogEntity>(
            predicate: #Predicate { $0.wordId == wordId && $0.at == at })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
