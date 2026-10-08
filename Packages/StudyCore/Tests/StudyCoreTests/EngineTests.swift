import Foundation
import Testing
@testable import StudyCore

@MainActor
@Suite struct StudyEngineTests {
    let start = date(2026, 10, 8, 12)

    private func learnAll(_ engine: StudyEngine, except hard: Set<String> = []) throws {
        var guardCount = 0
        while case .card(let id) = engine.phase, guardCount < 1000 {
            try engine.perform(hard.contains(id) ? .stillLearning : .learned)
            if hard.contains(id) && engine.plan.queue.allSatisfy(hard.contains) { break }
            guardCount += 1
        }
    }

    // MARK: day 1

    @Test func firstLaunchOpensAPlanOfSixtyNewWords() throws {
        let now = TestNow(start)
        let engine = try makeEngine(catalog: makeCatalog(), now: now)
        #expect(engine.plan.wordIds.count == 60)
        #expect(engine.plan.dayKey == DayKey(year: 2026, month: 10, day: 8))
        #expect(engine.reviewDueCount == 0)
        guard case .card(let id) = engine.phase else { Issue.record("expected a card"); return }
        #expect(id == engine.plan.wordIds[0])
        #expect(engine.currentWord?.id == id)
    }

    @Test func reopeningTheSameDayKeepsThePlanWithoutRebuilding() throws {
        let now = TestNow(start)
        let repository = InMemoryProgressRepository()
        let catalog = try makeCatalog()
        let first = try makeEngine(catalog: catalog, repository: repository, now: now)
        try first.perform(.learned)
        try first.perform(.stillLearning)
        now.value = date(2026, 10, 8, 22)

        let second = try makeEngine(catalog: catalog, repository: repository, now: now)
        #expect(second.plan == first.plan)
        #expect(second.progress == first.progress)
        #expect(try second.refreshDay() == false)
    }

    @Test func everyActionIsPersistedImmediately() throws {
        let now = TestNow(start)
        let repository = InMemoryProgressRepository()
        let engine = try makeEngine(catalog: makeCatalog(), repository: repository, now: now)
        let firstId = try #require(engine.plan.currentWordId)
        try engine.perform(.learned)

        // A "crash": a fresh engine on the same storage sees the action.
        let reopened = try makeEngine(catalog: makeCatalog(), repository: repository, now: now)
        #expect(reopened.progress[firstId]?.status == .review)
        #expect(reopened.plan.learnedIds == [firstId])
        #expect(try repository.log(on: engine.today).count == 1)
    }

    @Test func changingTheDailyCountOnlyAffectsTheNextPlan() throws {
        let now = TestNow(start)
        let engine = try makeEngine(catalog: makeCatalog(), now: now)
        engine.settings.newWordsPerDay = 30
        #expect(engine.plan.wordIds.count == 60)
        now.advance(days: 1)
        try engine.refreshDay()
        #expect(engine.plan.wordIds.count == 30)
    }

    @Test func moreWordsExtendTheTodayPlan() throws {
        let now = TestNow(start)
        let engine = try makeEngine(catalog: makeCatalog(), now: now)
        try learnAll(engine)
        #expect(engine.phase == .dayComplete)
        #expect(try engine.addMoreWords() == 10)
        #expect(engine.plan.totalCount == 70 && engine.plan.learnedCount == 60)
        #expect(engine.plan.queue.count == 10)
        guard case .card = engine.phase else { Issue.record("expected a card"); return }
        #expect(!engine.canUndoLearn)
    }

    // MARK: three-day scenario from the acceptance criteria

    @Test func threeDayScenario() throws {
        let now = TestNow(start)
        let catalog = try makeCatalog()
        let repository = InMemoryProgressRepository()
        let engine = try makeEngine(catalog: catalog, repository: repository, now: now)

        // Day 1: 60 words, five are marked "still learning".
        let day1 = engine.plan.wordIds
        let hard = Set(day1.prefix(5))
        try learnAll(engine, except: hard)
        for id in hard { #expect(engine.status(of: id) == .learning) }
        #expect(engine.plan.learnedCount == 55)
        guard case .roundComplete(let remaining) = engine.phase else { Issue.record("round should be complete"); return }
        #expect(remaining == 5)
        try engine.finishForToday()
        #expect(engine.phase == .dayComplete)

        // Day 2: the five hard words come first, the learned ones are due for review.
        now.advance(days: 1)
        #expect(try engine.refreshDay())
        #expect(Set(engine.plan.wordIds.prefix(5)) == hard)
        #expect(engine.plan.wordIds.count == 65)
        #expect(engine.reviewDueCount == 55)
        #expect(Set(engine.reviewQueue).isDisjoint(with: Set(engine.plan.wordIds)))

        // Review: remember 50, forget 5.
        var forgotten: [String] = []
        for index in 0..<55 {
            let id = try #require(engine.reviewQueue.first)
            if index < 5 { forgotten.append(id); try engine.answer(.forgot) } else { try engine.answer(.remembered) }
        }
        #expect(engine.reviewDueCount == 0)
        #expect(engine.reviewsAnsweredToday == 55)

        // Day 3: the forgotten words are carried over together with the unfinished ones.
        now.advance(days: 1)
        try engine.refreshDay()
        #expect(Set(engine.plan.wordIds.prefix(10)) == hard.union(forgotten))
        for id in forgotten { #expect(engine.progress[id]?.lapses == 1) }
        // Remembered words have moved to box 2, due in three days.
        let remembered = try #require(day1.first { !hard.contains($0) && !forgotten.contains($0) })
        #expect(engine.progress[remembered]?.box == 2)
        #expect(engine.progress[remembered]?.dueDayKey == DayKey(year: 2026, month: 10, day: 8).adding(days: 1 + 3))
    }

    // MARK: day change

    @Test func midnightDoesNotChangeTheStudyDayButFourAmDoes() throws {
        let now = TestNow(date(2026, 10, 8, 23, 0))
        let engine = try makeEngine(catalog: makeCatalog(), now: now)
        let plan = engine.plan
        now.value = date(2026, 10, 9, 1, 30)
        #expect(try engine.refreshDay() == false)
        #expect(engine.plan == plan)
        #expect(engine.secondsUntilNextDay == 2.5 * 3600)
        now.value = date(2026, 10, 9, 4, 0)
        #expect(try engine.refreshDay())
        #expect(engine.today == DayKey(year: 2026, month: 10, day: 9))
    }

    @Test func changingTheStartHourRecomputesTheCountdown() throws {
        let now = TestNow(date(2026, 10, 8, 20, 0))
        let engine = try makeEngine(catalog: makeCatalog(), now: now)
        #expect(engine.secondsUntilNextDay == 8 * 3600)
        engine.settings.dayStartHour = 6
        #expect(engine.secondsUntilNextDay == 10 * 3600)
    }

    @Test func aNewDayClearsUndo() throws {
        let now = TestNow(start)
        let engine = try makeEngine(catalog: makeCatalog(), now: now)
        try engine.perform(.learned)
        #expect(engine.canUndoLearn)
        now.advance(days: 1)
        try engine.refreshDay()
        #expect(!engine.canUndoLearn)
        #expect(throws: StudyError.nothingToUndo) { try engine.undoLearn() }
    }

    // MARK: undo

    @Test func undoRestoresProgressPlanAndLogExactly() throws {
        let now = TestNow(start)
        let repository = InMemoryProgressRepository()
        let engine = try makeEngine(catalog: makeCatalog(), repository: repository, now: now)
        try engine.perform(.stillLearning)                // so the next undo targets a word with history
        let planBefore = engine.plan
        let progressBefore = engine.progress
        let logBefore = try repository.allLog()

        try engine.perform(.learned)
        try engine.perform(.known)
        try engine.undoLearn()
        try engine.undoLearn()

        #expect(engine.plan == planBefore)
        #expect(engine.progress == progressBefore)
        #expect(try repository.allLog() == logBefore)
        #expect(try repository.plan(for: engine.today) == planBefore)
    }

    @Test func undoWorksTenStepsDeepThenStops() throws {
        let now = TestNow(start)
        let engine = try makeEngine(catalog: makeCatalog(), now: now)
        let original = engine.plan
        for _ in 0..<12 { try engine.perform(.learned) }
        for _ in 0..<10 { try engine.undoLearn() }
        #expect(engine.plan.learnedCount == 2)
        #expect(throws: StudyError.nothingToUndo) { try engine.undoLearn() }
        #expect(engine.plan.wordIds == original.wordIds)
    }

    @Test func undoingAReviewAnswerRestoresTheWordAndTheCounter() throws {
        let now = TestNow(start)
        let engine = try makeEngine(catalog: makeCatalog(), now: now)
        try learnAll(engine)
        now.advance(days: 1)
        try engine.refreshDay()
        let id = try #require(engine.reviewQueue.first)
        let before = try #require(engine.progress[id])
        try engine.answer(.forgot)
        #expect(engine.reviewsAnsweredToday == 1 && engine.progress[id]?.status == .learning)
        try engine.undoReview()
        #expect(engine.progress[id] == before)
        #expect(engine.reviewsAnsweredToday == 0)
        #expect(engine.reviewQueue.first == id)
    }

    // MARK: review limit and badge

    @Test func reviewLimitIsAPerDayCapIncludingAnsweredCards() throws {
        let now = TestNow(start)
        var settings = StudySettings()
        settings.reviewLimit = 20
        let engine = try makeEngine(catalog: makeCatalog(), settings: settings, now: now)
        try learnAll(engine)
        now.advance(days: 1)
        try engine.refreshDay()
        #expect(engine.reviewDueCount == 20)
        for _ in 0..<5 { try engine.answer(.remembered) }
        #expect(engine.reviewDueCount == 15)
        #expect(engine.plan.reviewTarget == 20)
    }

    // MARK: dictionary actions

    @Test func markingKnownRemovesTheWordFromPlanAndFuture() throws {
        let now = TestNow(start)
        let engine = try makeEngine(catalog: makeCatalog(), now: now)
        let id = engine.plan.wordIds[7]
        try engine.markKnown(id)
        #expect(!engine.plan.wordIds.contains(id) && !engine.plan.queue.contains(id))
        #expect(engine.status(of: id) == .known)
        now.advance(days: 1)
        try engine.refreshDay()
        #expect(!engine.plan.wordIds.contains(id))
    }

    @Test func returningToLearningCarriesTheWordOverToTomorrow() throws {
        let now = TestNow(start)
        let engine = try makeEngine(catalog: makeCatalog(), now: now)
        let id = engine.plan.wordIds[0]
        try engine.markKnown(id)
        try engine.returnToLearning(id)
        #expect(engine.status(of: id) == .learning)
        now.advance(days: 1)
        try engine.refreshDay()
        #expect(engine.plan.wordIds.first == id)
    }

    @Test func resetMakesTheWordNewAgainButKeepsTheFavouriteMark() throws {
        let now = TestNow(start)
        let engine = try makeEngine(catalog: makeCatalog(), now: now)
        let id = engine.plan.wordIds[0]
        try engine.toggleFavorite(id)
        try engine.perform(.learned)
        try engine.reset(id)
        #expect(engine.progress[id] == WordProgress(wordId: id, isFavorite: true))
        #expect(!engine.plan.wordIds.contains(id))
    }

    @Test func addingToTodayAppendsToTheQueue() throws {
        let now = TestNow(start)
        let engine = try makeEngine(catalog: makeCatalog(), now: now)
        try engine.addToToday("w99")
        #expect(engine.plan.queue.last == "w99" && engine.plan.wordIds.last == "w99")
        try engine.addToToday("w99")  // second time is a no-op
        #expect(engine.plan.wordIds.filter { $0 == "w99" }.count == 1)
    }

    // MARK: end of the dictionary

    @Test func allDoneWhenEverythingIsFinished() throws {
        let now = TestNow(start)
        let engine = try makeEngine(catalog: makeCatalog(ox3000: 5, ox5000: 0), now: now)
        try learnAll(engine)
        #expect(engine.phase == .dayComplete)
        #expect(try engine.addMoreWords() == 0)
        now.advance(days: 1)
        try engine.refreshDay()
        #expect(engine.plan.wordIds.isEmpty)
        #expect(engine.phase == .allDone)
    }

    // MARK: streak

    @Test func streakGrowsAcrossDaysAndResetsAfterAGap() throws {
        let now = TestNow(start)
        let engine = try makeEngine(catalog: makeCatalog(ox3000: 300, ox5000: 0), now: now)
        for _ in 0..<3 {
            try learnAll(engine)
            now.advance(days: 1)
            try engine.refreshDay()
        }
        #expect(try engine.currentStreak() == 3)       // today not finished yet
        #expect(try engine.bestStreak() == 3)
        now.advance(days: 2)                           // two days skipped
        try engine.refreshDay()
        #expect(try engine.currentStreak() == 0)
        #expect(try engine.bestStreak() == 3)
    }
}
