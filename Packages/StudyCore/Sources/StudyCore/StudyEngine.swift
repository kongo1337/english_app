import Foundation

/// Orchestrates one user's study: keeps today's plan and the progress in memory, applies
/// every action through the pure rules, and persists it atomically before updating memory.
///
/// The app wraps it in an `@Observable` service; all behaviour lives here so it can be
/// tested without a simulator. The engine never reads the system clock itself: `now` is
/// supplied by the caller.
@MainActor
public final class StudyEngine {
    public let catalog: WordCatalog
    public var settings: StudySettings {
        didSet { clock.dayStartHour = min(max(settings.dayStartHour, 0), 23) }
    }
    public private(set) var clock: DayClock

    public private(set) var today: DayKey
    public private(set) var plan: DailyPlan
    public private(set) var progress: [String: WordProgress]
    /// Words to repeat now, the most overdue first (empty once the daily limit is reached).
    public private(set) var reviewQueue: [String] = []
    public private(set) var reviewsAnsweredToday: Int

    private let repository: ProgressRepository
    private let now: @MainActor () -> Date
    private var learnUndo = UndoStack()
    private var reviewUndo = UndoStack()

    public init(
        catalog: WordCatalog, repository: ProgressRepository, settings: StudySettings,
        clock: DayClock, now: @escaping @MainActor () -> Date
    ) throws {
        var clock = clock
        clock.dayStartHour = min(max(settings.dayStartHour, 0), 23)
        let day = clock.dayKey(for: now())
        let progress = try repository.allProgress()

        self.catalog = catalog
        self.repository = repository
        self.settings = settings
        self.clock = clock
        self.now = now
        self.today = day
        self.progress = progress
        self.plan = DailyPlan(dayKey: day, wordIds: [])
        self.reviewsAnsweredToday = 0
        try openDay(day)
    }

    // MARK: - Day handling

    /// Call when the app becomes active and when the countdown reaches zero. Returns true if
    /// a new study day started (a new plan was opened).
    @discardableResult
    public func refreshDay() throws -> Bool {
        let day = clock.dayKey(for: now())
        guard day != today else { return false }
        try openDay(day)
        return true
    }

    /// Seconds until the next study day starts.
    public var secondsUntilNextDay: TimeInterval { clock.secondsUntilNextDay(from: now()) }

    private func openDay(_ day: DayKey) throws {
        today = day
        learnUndo.removeAll()
        reviewUndo.removeAll()
        reviewsAnsweredToday = try repository.log(on: day).filter { $0.mode == .review }.count

        if let stored = try repository.plan(for: day) {
            plan = stored
        } else {
            let target = ReviewQueueBuilder.queue(
                catalog: catalog, progress: progress, today: day, limit: settings.reviewLimit
            ).count
            let fresh = DailyPlanBuilder.build(
                dayKey: day, catalog: catalog, progress: progress, settings: settings,
                reviewTarget: target)
            try repository.commit(StateChange(plan: fresh))
            plan = fresh
        }
        recomputeReviewQueue()
    }

    // MARK: - Learn

    public var phase: LearnPhase {
        let hasMore = plan.queue.isEmpty && plan.wordIds.isEmpty && hasNewWords
        return LearnSession.phase(of: plan, hasMoreNewWords: hasMore)
    }

    public var currentWord: Word? { plan.currentWordId.flatMap(catalog.word(id:)) }

    public var canUndoLearn: Bool { !learnUndo.isEmpty }

    /// True while enabled lists still have words that were never shown.
    public var hasNewWords: Bool {
        catalog.words.contains { word in
            settings.enabledLists.contains(word.list)
                && !plan.wordIds.contains(word.id)
                && (progress[word.id]?.status ?? .new) == .new
        }
    }

    /// Applies an action to the card on screen.
    @discardableResult
    public func perform(_ action: LearnAction) throws -> ActionResult {
        guard let id = plan.currentWordId else { throw StudyError.wordNotInQueue("") }
        let result = try LearnSession.apply(
            action, wordId: id, plan: plan, progress: progress[id], today: today, now: now())
        try repository.commit(
            StateChange(progress: [result.progress], plan: result.plan, appendedLog: [result.log]))
        progress[id] = result.progress
        if let next = result.plan { plan = next }
        learnUndo.push(result.undo)
        recomputeReviewQueue()
        return result
    }

    public func undoLearn() throws {
        guard let record = learnUndo.pop() else { throw StudyError.nothingToUndo }
        do {
            try repository.commit(change(reverting: record))
        } catch {
            learnUndo.push(record)
            throw error
        }
        progress[record.wordId] = record.previousProgress
        if let previous = record.previousPlan { plan = previous }
        recomputeReviewQueue()
    }

    /// "Пройти ещё раз": go through the remaining hard cards once more.
    public func continueRound() throws {
        try update(plan: LearnSession.startNextRound(plan))
    }

    /// "На сегодня хватит": remaining cards stay "still learning" for tomorrow.
    public func finishForToday() throws {
        try update(plan: LearnSession.finishForToday(plan))
    }

    /// "Ещё 10 слов". Returns how many words were added (0 when the lists are exhausted).
    @discardableResult
    public func addMoreWords() throws -> Int {
        let ids = DailyPlanBuilder.extraWords(
            plan: plan, catalog: catalog, progress: progress, settings: settings)
        guard !ids.isEmpty else { return 0 }
        try update(plan: LearnSession.addWords(ids, to: plan))
        return ids.count
    }

    /// Plan changes that are not card actions cannot be undone, and they invalidate older
    /// snapshots, so the undo stack is dropped.
    private func update(plan next: DailyPlan) throws {
        try repository.commit(StateChange(plan: next))
        plan = next
        learnUndo.removeAll()
        recomputeReviewQueue()
    }

    // MARK: - Review

    public var reviewDueCount: Int { reviewQueue.count }

    public var currentReviewWord: Word? { reviewQueue.first.flatMap(catalog.word(id:)) }

    public var canUndoReview: Bool { !reviewUndo.isEmpty }

    @discardableResult
    public func answer(_ answer: ReviewAnswer) throws -> ActionResult {
        guard let id = reviewQueue.first else { throw StudyError.wordNotInQueue("") }
        let result = LearnSession.review(
            answer, wordId: id, progress: progress[id], today: today, now: now())
        try repository.commit(StateChange(progress: [result.progress], appendedLog: [result.log]))
        progress[id] = result.progress
        reviewsAnsweredToday += 1
        reviewUndo.push(result.undo)
        recomputeReviewQueue()
        return result
    }

    public func undoReview() throws {
        guard let record = reviewUndo.pop() else { throw StudyError.nothingToUndo }
        do {
            try repository.commit(change(reverting: record))
        } catch {
            reviewUndo.push(record)
            throw error
        }
        progress[record.wordId] = record.previousProgress
        reviewsAnsweredToday = max(0, reviewsAnsweredToday - 1)
        recomputeReviewQueue()
    }

    private func change(reverting record: UndoRecord) -> StateChange {
        StateChange(
            progress: record.previousProgress.map { [$0] } ?? [],
            removedProgress: record.previousProgress == nil ? [record.wordId] : [],
            plan: record.previousPlan, removedLog: [record.logKey])
    }

    private func recomputeReviewQueue() {
        reviewQueue = ReviewQueueBuilder.queue(
            catalog: catalog, progress: progress, today: today, excluding: Set(plan.wordIds),
            answeredToday: reviewsAnsweredToday, limit: settings.reviewLimit)
    }

    // MARK: - Dictionary actions

    public func status(of id: String) -> WordStatus { progress[id]?.status ?? .new }

    public func markKnown(_ id: String) throws {
        try applyManual(id, result: .known) { ProgressRules.markKnown($0, now: now()) }
    }

    public func returnToLearning(_ id: String) throws {
        try applyManual(id, result: .returnedToLearning) { ProgressRules.returnToLearning($0, now: now()) }
    }

    public func reset(_ id: String) throws {
        try applyManual(id, result: .reset) { ProgressRules.reset($0) }
    }

    public func toggleFavorite(_ id: String) throws {
        let next = ProgressRules.toggleFavorite(progress[id] ?? .fresh(id))
        try repository.commit(StateChange(progress: [next]))
        progress[id] = next
    }

    /// "Добавить в сегодняшний набор".
    public func addToToday(_ id: String) throws {
        guard catalog.contains(id), !plan.wordIds.contains(id) else { return }
        var next = plan
        next.wordIds.append(id)
        next.queue.append(id)
        try update(plan: next)
    }

    private func applyManual(
        _ id: String, result: LogResult, transform: (WordProgress) -> WordProgress
    ) throws {
        let updated = transform(progress[id] ?? .fresh(id))
        var nextPlan = plan
        nextPlan.wordIds.removeAll { $0 == id }
        nextPlan.queue.removeAll { $0 == id }
        nextPlan.learnedIds.remove(id)
        nextPlan.seenIds.remove(id)
        // A word that becomes "still learning" by hand is not injected into today's plan.
        let log = ReviewLogEntry(wordId: id, at: now(), dayKey: today, mode: .manual, result: result)
        try repository.commit(
            StateChange(progress: [updated], plan: nextPlan == plan ? nil : nextPlan, appendedLog: [log]))
        progress[id] = updated
        if nextPlan != plan {
            plan = nextPlan
            learnUndo.removeAll()
        }
        recomputeReviewQueue()
    }

    // MARK: - Backup and reset

    /// Everything stored, for the backup file.
    public func snapshot() throws -> BackupPayload {
        BackupPayload(
            progress: progress.values.sorted { $0.wordId < $1.wordId },
            plans: try repository.allPlans(),
            log: try repository.allLog())
    }

    /// Replaces all progress with a backup (the caller has validated it) and opens today.
    public func restore(_ payload: BackupPayload) throws {
        try repository.replaceAll(progress: payload.progress, plans: payload.plans, log: payload.log)
        try reload()
    }

    /// "Сбросить весь прогресс": back to a fresh install.
    public func eraseAll() throws {
        try repository.eraseAll()
        try reload()
    }

    private func reload() throws {
        progress = try repository.allProgress()
        plan = DailyPlan(dayKey: today, wordIds: [])
        try openDay(clock.dayKey(for: now()))
    }

    // MARK: - Statistics

    public func daySummaries() throws -> [DaySummary] {
        StatsCalculator.summaries(plans: try repository.allPlans(), log: try repository.allLog())
    }

    /// New words learned on each of the last `days` days, oldest first, ending today.
    public func learnedPerDay(days: Int = 30) throws -> [DayCount] {
        StatsCalculator.learnedPerDay(log: try repository.allLog(), today: today, days: days)
    }

    public func currentStreak() throws -> Int {
        StatsCalculator.currentStreak(try daySummaries(), today: today)
    }

    public func bestStreak() throws -> Int {
        StatsCalculator.bestStreak(try daySummaries())
    }
}
