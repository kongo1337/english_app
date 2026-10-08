import Foundation

public enum LearnAction: Equatable, Sendable {
    /// "Выучил": the word goes to spaced repetition.
    case learned
    /// "Ещё учу": the word comes back in a few cards and tomorrow.
    case stillLearning
    /// "Уже знаю": the word is removed for good.
    case known
}

public enum StudyError: Error, Equatable {
    case wordNotInQueue(String)
    case nothingToUndo
}

/// What a card action changed. The first three are what must be persisted; `undo` is what
/// restores the exact previous state.
public struct ActionResult: Equatable, Sendable {
    public let progress: WordProgress
    /// The updated plan; nil for review answers, which do not touch the plan.
    public let plan: DailyPlan?
    public let log: ReviewLogEntry
    public let undo: UndoRecord
}

/// Snapshot taken before an action; applying it reverts the action exactly.
public struct UndoRecord: Equatable, Sendable {
    public let wordId: String
    /// Nil when the word had no progress row before the action; undoing deletes the row.
    public let previousProgress: WordProgress?
    public let previousPlan: DailyPlan?
    public let logKey: LogKey
}

/// A bounded stack of undo snapshots. It is cleared when the study day changes.
public struct UndoStack: Equatable, Sendable {
    public static let capacity = 10
    public private(set) var records: [UndoRecord] = []

    public init() {}

    public var isEmpty: Bool { records.isEmpty }
    public var count: Int { records.count }

    public mutating func push(_ record: UndoRecord) {
        records.append(record)
        if records.count > Self.capacity { records.removeFirst(records.count - Self.capacity) }
    }

    public mutating func pop() -> UndoRecord? { records.popLast() }

    public mutating func removeAll() { records.removeAll() }
}

/// What the Learn tab should show.
public enum LearnPhase: Equatable, Sendable {
    /// A card is waiting.
    case card(wordId: String)
    /// Every remaining card has been shown in this round; ask whether to go on.
    case roundComplete(remaining: Int)
    /// Nothing left for today.
    case dayComplete
    /// No cards today and no new words left in the enabled lists.
    case allDone
}

public enum LearnSession {
    /// A card marked "still learning" returns after this many other cards.
    public static let repeatGap = 7

    public static func apply(
        _ action: LearnAction, wordId: String, plan: DailyPlan, progress existing: WordProgress?,
        today: DayKey, now: Date
    ) throws -> ActionResult {
        let progress = existing ?? .fresh(wordId)
        guard let position = plan.queue.firstIndex(of: wordId) else {
            throw StudyError.wordNotInQueue(wordId)
        }
        var nextPlan = plan
        nextPlan.queue.remove(at: position)
        nextPlan.seenIds.insert(wordId)

        let nextProgress: WordProgress
        let result: LogResult
        switch action {
        case .learned:
            nextPlan.learnedIds.insert(wordId)
            nextProgress = LeitnerScheduler.learned(progress, today: today, now: now)
            result = .learned
        case .stillLearning:
            nextPlan.queue.insert(wordId, at: min(repeatGap, nextPlan.queue.count))
            nextProgress = LeitnerScheduler.stillLearning(progress, now: now)
            result = .stillLearning
        case .known:
            nextPlan.wordIds.removeAll { $0 == wordId }
            nextPlan.learnedIds.remove(wordId)
            nextPlan.seenIds.remove(wordId)
            nextProgress = ProgressRules.markKnown(progress, now: now)
            result = .known
        }
        let log = ReviewLogEntry(wordId: wordId, at: now, dayKey: today, mode: .learn, result: result)
        return ActionResult(
            progress: nextProgress, plan: nextPlan, log: log,
            undo: UndoRecord(
                wordId: wordId, previousProgress: existing, previousPlan: plan, logKey: log.key))
    }

    /// Answer to a card in the Review tab.
    public static func review(
        _ answer: ReviewAnswer, wordId: String, progress existing: WordProgress?, today: DayKey,
        now: Date
    ) -> ActionResult {
        let progress = existing ?? .fresh(wordId)
        let next = LeitnerScheduler.answer(answer, to: progress, today: today, now: now)
        let log = ReviewLogEntry(
            wordId: progress.wordId, at: now, dayKey: today, mode: .review,
            result: answer == .remembered ? .remembered : .forgot)
        return ActionResult(
            progress: next, plan: nil, log: log,
            undo: UndoRecord(
                wordId: wordId, previousProgress: existing, previousPlan: nil, logKey: log.key))
    }

    public static func phase(of plan: DailyPlan, hasMoreNewWords: Bool) -> LearnPhase {
        guard let current = plan.queue.first else {
            return plan.wordIds.isEmpty && !hasMoreNewWords ? .allDone : .dayComplete
        }
        if plan.queue.allSatisfy(plan.seenIds.contains) {
            return .roundComplete(remaining: plan.queue.count)
        }
        return .card(wordId: current)
    }

    /// "Пройти ещё раз": starts a new round with the remaining cards.
    public static func startNextRound(_ plan: DailyPlan) -> DailyPlan {
        var next = plan
        next.seenIds = []
        return next
    }

    /// "На сегодня хватит": the remaining cards stay "still learning" and return tomorrow.
    public static func finishForToday(_ plan: DailyPlan) -> DailyPlan {
        var next = plan
        next.queue = []
        return next
    }

    /// "Ещё 10 слов": appends fresh cards to today's plan and queue.
    public static func addWords(_ ids: [String], to plan: DailyPlan) -> DailyPlan {
        var next = plan
        let added = ids.filter { !plan.wordIds.contains($0) }
        next.wordIds += added
        next.queue += added
        next.extraBatches += 1
        return next
    }
}
