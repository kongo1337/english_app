import Foundation

/// Everything a single user action changes. A repository must apply it atomically:
/// after a crash either the whole action is stored or none of it.
public struct StateChange: Equatable, Sendable {
    public var progress: [WordProgress]
    public var removedProgress: [String]
    public var plan: DailyPlan?
    public var appendedLog: [ReviewLogEntry]
    public var removedLog: [LogKey]

    public init(
        progress: [WordProgress] = [], removedProgress: [String] = [], plan: DailyPlan? = nil,
        appendedLog: [ReviewLogEntry] = [], removedLog: [LogKey] = []
    ) {
        self.progress = progress
        self.removedProgress = removedProgress
        self.plan = plan
        self.appendedLog = appendedLog
        self.removedLog = removedLog
    }
}

/// Storage of the user's progress. The app implements it with SwiftData; tests use
/// `InMemoryProgressRepository`.
@MainActor
public protocol ProgressRepository: AnyObject {
    func allProgress() throws -> [String: WordProgress]
    func plan(for day: DayKey) throws -> DailyPlan?
    func allPlans() throws -> [DailyPlan]
    func log(on day: DayKey) throws -> [ReviewLogEntry]
    func allLog() throws -> [ReviewLogEntry]
    func commit(_ change: StateChange) throws
    /// Deletes all progress, plans and log (the "reset everything" button).
    func eraseAll() throws
    /// Replaces everything with a backup.
    func replaceAll(progress: [WordProgress], plans: [DailyPlan], log: [ReviewLogEntry]) throws
}

@MainActor
public final class InMemoryProgressRepository: ProgressRepository {
    private var progress: [String: WordProgress] = [:]
    private var plans: [DayKey: DailyPlan] = [:]
    private var entries: [ReviewLogEntry] = []

    public init() {}

    public func allProgress() throws -> [String: WordProgress] { progress }

    public func plan(for day: DayKey) throws -> DailyPlan? { plans[day] }

    public func allPlans() throws -> [DailyPlan] { plans.values.sorted { $0.dayKey < $1.dayKey } }

    public func log(on day: DayKey) throws -> [ReviewLogEntry] { entries.filter { $0.dayKey == day } }

    public func allLog() throws -> [ReviewLogEntry] { entries }

    public func commit(_ change: StateChange) throws {
        for item in change.progress { progress[item.wordId] = item }
        for id in change.removedProgress { progress[id] = nil }
        if let plan = change.plan { plans[plan.dayKey] = plan }
        for key in change.removedLog {
            if let index = entries.firstIndex(where: { $0.key == key }) { entries.remove(at: index) }
        }
        entries += change.appendedLog
    }

    public func eraseAll() throws {
        progress = [:]
        plans = [:]
        entries = []
    }

    public func replaceAll(progress: [WordProgress], plans: [DailyPlan], log: [ReviewLogEntry]) throws {
        self.progress = Dictionary(uniqueKeysWithValues: progress.map { ($0.wordId, $0) })
        self.plans = Dictionary(uniqueKeysWithValues: plans.map { ($0.dayKey, $0) })
        self.entries = log
    }
}
