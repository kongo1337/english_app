import Foundation
import Testing
@testable import StudyCore

private let day = DayKey(year: 2026, month: 10, day: 8)
private let tomorrow = DayKey(year: 2026, month: 10, day: 9)
private let now = date(2026, 10, 8, 12)

private func plan(_ count: Int) -> DailyPlan {
    DailyPlan(dayKey: day, wordIds: (1...count).map { "w\($0)" })
}

private func act(_ action: LearnAction, _ id: String, on plan: DailyPlan, progress: WordProgress? = nil) throws -> ActionResult {
    try LearnSession.apply(action, wordId: id, plan: plan, progress: progress ?? .fresh(id), today: day, now: now)
}

@Suite struct LearnSessionTests {
    @Test func learnedMovesTheWordToBoxOneDueTomorrow() throws {
        let result = try act(.learned, "w1", on: plan(10))
        #expect(result.progress.status == .review)
        #expect(result.progress.box == 1)
        #expect(result.progress.dueDayKey == tomorrow)
        #expect(result.progress.timesSeen == 1)
        #expect(result.progress.firstSeenAt == now && result.progress.lastSeenAt == now)
        let next = try #require(result.plan)
        #expect(next.queue == (2...10).map { "w\($0)" })
        #expect(next.learnedIds == ["w1"])
        #expect(next.wordIds.count == 10)
        #expect(result.log.result == .learned && result.log.mode == .learn && result.log.dayKey == day)
    }

    @Test func stillLearningReturnsAfterSevenCards() throws {
        let result = try act(.stillLearning, "w1", on: plan(20))
        let queue = try #require(result.plan).queue
        #expect(queue.count == 20)
        #expect(queue.firstIndex(of: "w1") == 7)
        #expect(queue.prefix(7) == ["w2", "w3", "w4", "w5", "w6", "w7", "w8"])
        #expect(result.progress.status == .learning && result.progress.box == 0)
        #expect(result.progress.dueDayKey == nil)
        #expect(try #require(result.plan).learnedIds.isEmpty)
    }

    @Test func stillLearningGoesToTheEndWhenFewCardsRemain() throws {
        let small = plan(4)
        let queue = try #require(try act(.stillLearning, "w1", on: small).plan).queue
        #expect(queue == ["w2", "w3", "w4", "w1"])
        let single = try #require(try act(.stillLearning, "w1", on: plan(1)).plan).queue
        #expect(single == ["w1"])
    }

    @Test func knownRemovesTheWordFromThePlanAndCountsDown() throws {
        let result = try act(.known, "w3", on: plan(10))
        let next = try #require(result.plan)
        #expect(!next.wordIds.contains("w3") && !next.queue.contains("w3"))
        #expect(next.totalCount == 9)
        #expect(result.progress.status == .known)
    }

    @Test func actingOnAWordOutsideTheQueueFails() {
        #expect(throws: StudyError.wordNotInQueue("zzz")) { try act(.learned, "zzz", on: plan(3)) }
    }

    @Test func undoRecordHoldsTheExactPreviousState() throws {
        let before = WordProgress(
            wordId: "w2", status: .learning, box: 0, firstSeenAt: date(2026, 10, 1), lastSeenAt: date(2026, 10, 7),
            timesSeen: 4, lapses: 2, isFavorite: true)
        let original = plan(5)
        let result = try act(.learned, "w2", on: original, progress: before)
        #expect(result.undo.previousProgress == before)
        #expect(result.undo.previousPlan == original)
        #expect(result.undo.logKey == result.log.key)
        // The favourite mark and lapses survive the action.
        #expect(result.progress.isFavorite && result.progress.lapses == 2 && result.progress.timesSeen == 5)
    }

    @Test func roundCompletesWhenOnlySeenCardsRemain() throws {
        var current = plan(3)
        #expect(LearnSession.phase(of: current, hasMoreNewWords: true) == .card(wordId: "w1"))
        current = try #require(try act(.stillLearning, "w1", on: current).plan)   // queue w2 w3 w1
        current = try #require(try act(.learned, "w2", on: current).plan)         // queue w3 w1
        #expect(LearnSession.phase(of: current, hasMoreNewWords: true) == .card(wordId: "w3"))
        current = try #require(try act(.stillLearning, "w3", on: current).plan)   // queue w1 w3
        #expect(LearnSession.phase(of: current, hasMoreNewWords: true) == .roundComplete(remaining: 2))

        // "Go through them again" starts a fresh round.
        current = LearnSession.startNextRound(current)
        #expect(LearnSession.phase(of: current, hasMoreNewWords: true) == .card(wordId: "w1"))
        current = try #require(try act(.stillLearning, "w1", on: current).plan)
        #expect(LearnSession.phase(of: current, hasMoreNewWords: true) == .card(wordId: "w3"))
    }

    @Test func finishingTheDayEmptiesTheQueueButKeepsTheCounts() throws {
        var current = plan(5)
        current = try #require(try act(.learned, "w1", on: current).plan)
        current = LearnSession.finishForToday(current)
        #expect(current.queue.isEmpty)
        #expect(current.learnedCount == 1 && current.totalCount == 5)
        #expect(LearnSession.phase(of: current, hasMoreNewWords: true) == .dayComplete)
    }

    @Test func allDoneNeedsAnEmptyPlanAndNoNewWordsLeft() {
        let empty = DailyPlan(dayKey: day, wordIds: [])
        #expect(LearnSession.phase(of: empty, hasMoreNewWords: false) == .allDone)
        #expect(LearnSession.phase(of: empty, hasMoreNewWords: true) == .dayComplete)
    }

    @Test func addingWordsAppendsToPlanAndQueueOnce() throws {
        var current = plan(3)
        current = try #require(try act(.learned, "w1", on: current).plan)
        let more = LearnSession.addWords(["w50", "w51", "w2"], to: current)  // w2 is already planned
        #expect(more.wordIds == ["w1", "w2", "w3", "w50", "w51"])
        #expect(more.queue == ["w2", "w3", "w50", "w51"])
        #expect(more.extraBatches == 1)
    }

    @Test func undoStackKeepsTheLastTen() throws {
        var stack = UndoStack()
        var current = plan(30)
        var records: [UndoRecord] = []
        for index in 1...15 {
            let result = try act(.learned, "w\(index)", on: current)
            current = try #require(result.plan)
            records.append(result.undo)
            stack.push(result.undo)
        }
        #expect(stack.count == 10)
        #expect(stack.pop() == records[14])
        #expect(stack.records.first == records[5])
    }
}

@Suite struct LeitnerTests {
    @Test func rememberingWalksThroughAllIntervals() {
        var progress = LeitnerScheduler.learned(.fresh("a"), today: day, now: now)
        #expect(progress.box == 1 && progress.dueDayKey == day.adding(days: 1))
        var today = day.adding(days: 1)
        var gaps: [Int] = []
        for _ in 0..<5 {
            progress = LeitnerScheduler.answer(.remembered, to: progress, today: today, now: now)
            #expect(progress.status == .review)
            let gap = today.days(until: try! #require(progress.dueDayKey))
            gaps.append(gap)
            today = progress.dueDayKey!
        }
        #expect(gaps == [3, 7, 14, 30, 60])
        #expect(progress.box == 6)
        progress = LeitnerScheduler.answer(.remembered, to: progress, today: today, now: now)
        #expect(progress.status == .mastered && progress.dueDayKey == nil && progress.box == 6)
    }

    @Test func forgettingSendsTheWordBackToLearning() {
        let before = WordProgress(wordId: "a", status: .review, box: 4, dueDayKey: day, timesSeen: 6, lapses: 1)
        let after = LeitnerScheduler.answer(.forgot, to: before, today: day, now: now)
        #expect(after.status == .learning && after.box == 0 && after.dueDayKey == nil)
        #expect(after.lapses == 2 && after.timesSeen == 7)
        #expect(!after.isHard)
        let hard = LeitnerScheduler.answer(.forgot, to: after, today: day, now: now)
        #expect(LeitnerScheduler.answer(.forgot, to: hard, today: day, now: now).isHard)
    }

    @Test func intervalsByBox() {
        #expect(LeitnerScheduler.interval(forBox: 1) == 1)
        #expect(LeitnerScheduler.interval(forBox: 6) == 60)
        #expect(LeitnerScheduler.interval(forBox: 0) == nil)
        #expect(LeitnerScheduler.interval(forBox: 7) == nil)
    }
}

@Suite struct ReviewQueueTests {
    private func due(_ id: String, _ daysFromToday: Int) -> WordProgress {
        WordProgress(wordId: id, status: .review, box: 2, dueDayKey: day.adding(days: daysFromToday))
    }

    @Test func listsOnlyDueWordsMostOverdueFirst() throws {
        let catalog = try makeCatalog()
        let progress = progressMap([
            due("w1", 0), due("w2", -3), due("w3", 1), due("w4", -1), due("w5", -3),
            WordProgress(wordId: "w6", status: .learning),
            WordProgress(wordId: "w7", status: .mastered),
        ])
        let queue = ReviewQueueBuilder.queue(catalog: catalog, progress: progress, today: day)
        #expect(queue == ["w2", "w5", "w4", "w1"])
    }

    @Test func respectsTheDailyLimitAndWhatWasAlreadyAnswered() throws {
        let catalog = try makeCatalog()
        let progress = progressMap((1...10).map { due("w\($0)", -$0) })
        #expect(ReviewQueueBuilder.queue(catalog: catalog, progress: progress, today: day, limit: 4).count == 4)
        #expect(ReviewQueueBuilder.queue(catalog: catalog, progress: progress, today: day, answeredToday: 3, limit: 4).count == 1)
        #expect(ReviewQueueBuilder.queue(catalog: catalog, progress: progress, today: day, answeredToday: 9, limit: 4).isEmpty)
        #expect(ReviewQueueBuilder.queue(catalog: catalog, progress: progress, today: day, limit: nil).count == 10)
    }

    @Test func wordsInTodaysPlanAreNotRepeated() throws {
        let catalog = try makeCatalog()
        let progress = progressMap([due("w1", 0), due("w2", 0)])
        #expect(ReviewQueueBuilder.queue(catalog: catalog, progress: progress, today: day, excluding: ["w1"]) == ["w2"])
    }

    @Test func skipsWordsMissingFromTheDictionary() throws {
        let catalog = try makeCatalog(ox3000: 5, ox5000: 0)
        #expect(ReviewQueueBuilder.queue(catalog: catalog, progress: progressMap([due("gone", 0)]), today: day).isEmpty)
    }
}
