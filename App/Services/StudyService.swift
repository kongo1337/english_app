import Foundation
import Observation
import StudyCore

/// The observable face of `StudyEngine`. All behaviour lives in the engine (and is tested on
/// Linux); this class republishes its state so SwiftUI redraws after every action, and keeps
/// the study day current while the app is open.
@MainActor
@Observable
final class StudyService {
    private(set) var today: DayKey
    private(set) var plan: DailyPlan
    private(set) var phase: LearnPhase
    private(set) var currentWord: Word?
    private(set) var reviewQueue: [String]
    private(set) var currentReviewWord: Word?
    private(set) var reviewsAnsweredToday: Int
    private(set) var canUndoLearn: Bool
    private(set) var canUndoReview: Bool
    private(set) var progress: [String: WordProgress]
    /// Set when the last operation failed (for example the disk is full); nil otherwise.
    private(set) var lastError: String?

    @ObservationIgnored let engine: StudyEngine
    @ObservationIgnored private var dayWatcher: Task<Void, Never>?

    init(engine: StudyEngine) {
        self.engine = engine
        today = engine.today
        plan = engine.plan
        phase = engine.phase
        currentWord = engine.currentWord
        reviewQueue = engine.reviewQueue
        currentReviewWord = engine.currentReviewWord
        reviewsAnsweredToday = engine.reviewsAnsweredToday
        canUndoLearn = engine.canUndoLearn
        canUndoReview = engine.canUndoReview
        progress = engine.progress
    }

    var catalog: WordCatalog { engine.catalog }
    var reviewDueCount: Int { reviewQueue.count }
    var secondsUntilNextDay: TimeInterval { engine.secondsUntilNextDay }
    var studySettings: StudySettings { engine.settings }
    /// True while enabled dictionaries still hold words that were never shown.
    var hasNewWords: Bool { engine.hasNewWords }

    func status(of id: String) -> WordStatus { progress[id]?.status ?? .new }

    // MARK: Learn

    func perform(_ action: LearnAction) { run { try engine.perform(action) } }
    func undoLearn() { run { try engine.undoLearn() } }
    func continueRound() { run { try engine.continueRound() } }
    func finishForToday() { run { try engine.finishForToday() } }
    func addMoreWords() { run { try engine.addMoreWords() } }

    // MARK: Review

    func answer(_ answer: ReviewAnswer) { run { try engine.answer(answer) } }
    func undoReview() { run { try engine.undoReview() } }

    // MARK: Dictionary

    func markKnown(_ id: String) { run { try engine.markKnown(id) } }
    func returnToLearning(_ id: String) { run { try engine.returnToLearning(id) } }
    func reset(_ id: String) { run { try engine.reset(id) } }
    func toggleFavorite(_ id: String) { run { try engine.toggleFavorite(id) } }
    func addToToday(_ id: String) { run { try engine.addToToday(id) } }

    // MARK: Statistics

    func currentStreak() -> Int { (try? engine.currentStreak()) ?? 0 }
    func bestStreak() -> Int { (try? engine.bestStreak()) ?? 0 }
    func daySummaries() -> [DaySummary] { (try? engine.daySummaries()) ?? [] }

    // MARK: Day and settings

    /// Opens a new plan when the study day has changed. Returns true if it did.
    @discardableResult
    func refreshDay() -> Bool {
        var changed = false
        run { changed = try engine.refreshDay() }
        return changed
    }

    /// Applies new study settings. They affect the plan of the next study day, except for the
    /// day start hour and the review limit, which apply immediately.
    func apply(_ settings: StudySettings) {
        engine.settings = settings
        refreshDay()
        sync()
    }

    /// Keeps the day current while the app runs: wakes up right after the day boundary.
    func startDayWatcher() {
        dayWatcher?.cancel()
        dayWatcher = Task { [weak self] in
            while !Task.isCancelled {
                guard let seconds = self?.engine.secondsUntilNextDay else { return }
                try? await Task.sleep(for: .seconds(max(1, seconds + 0.3)))
                if Task.isCancelled { return }
                self?.refreshDay()
            }
        }
    }

    func stopDayWatcher() {
        dayWatcher?.cancel()
        dayWatcher = nil
    }

    // MARK: Plumbing

    private func run(_ work: () throws -> Void) {
        do {
            try work()
            lastError = nil
        } catch {
            lastError = String(describing: error)
        }
        sync()
    }

    private func sync() {
        today = engine.today
        plan = engine.plan
        phase = engine.phase
        currentWord = engine.currentWord
        reviewQueue = engine.reviewQueue
        currentReviewWord = engine.currentReviewWord
        reviewsAnsweredToday = engine.reviewsAnsweredToday
        canUndoLearn = engine.canUndoLearn
        canUndoReview = engine.canUndoReview
        progress = engine.progress
    }
}
