import Foundation
import Testing
@testable import StudyCore

private let today = DayKey(year: 2026, month: 10, day: 8)

private func summary(_ offset: Int, plan: Int = 60, learned: Int = 0, target: Int = 0, answered: Int = 0) -> DaySummary {
    DaySummary(dayKey: today.adding(days: offset), planSize: plan, learned: learned, reviewTarget: target, reviewsAnswered: answered)
}

@Suite struct StatsTests {
    @Test func aDayCountsAtEightyPercentOfThePlanOrAllReviews() {
        #expect(summary(0, plan: 60, learned: 48).isCompleted)
        #expect(!summary(0, plan: 60, learned: 47).isCompleted)
        #expect(summary(0, plan: 60, learned: 0, target: 22, answered: 22).isCompleted)
        #expect(!summary(0, plan: 60, learned: 0, target: 22, answered: 21).isCompleted)
        #expect(!summary(0, plan: 0, learned: 0, target: 0, answered: 0).isCompleted)
    }

    @Test func streakCountsConsecutiveCompletedDays() {
        let days = [summary(-3, learned: 60), summary(-2, learned: 60), summary(-1, learned: 55), summary(0, learned: 60)]
        #expect(StatsCalculator.currentStreak(days, today: today) == 4)
    }

    @Test func unfinishedTodayDoesNotBreakTheStreak() {
        let days = [summary(-2, learned: 60), summary(-1, learned: 60), summary(0, learned: 5)]
        #expect(StatsCalculator.currentStreak(days, today: today) == 2)
    }

    @Test func aMissedDayResetsTheStreak() {
        let days = [summary(-5, learned: 60), summary(-4, learned: 60), summary(-3, learned: 60), summary(-1, learned: 60), summary(0, learned: 60)]
        #expect(StatsCalculator.currentStreak(days, today: today) == 2)
        #expect(StatsCalculator.bestStreak(days) == 3)
        #expect(StatsCalculator.currentStreak(days, today: today.adding(days: 3)) == 0)
    }

    @Test func bestStreakOfNothingIsZero() {
        #expect(StatsCalculator.bestStreak([]) == 0)
        #expect(StatsCalculator.currentStreak([], today: today) == 0)
    }

    @Test func summariesJoinPlansWithReviewLog() {
        let plan = DailyPlan(dayKey: today, wordIds: ["a", "b", "c", "d"], learnedIds: ["a", "b"], reviewTarget: 2)
        let log = [
            ReviewLogEntry(wordId: "x", at: date(2026, 10, 8), dayKey: today, mode: .review, result: .remembered),
            ReviewLogEntry(wordId: "y", at: date(2026, 10, 8, 13), dayKey: today, mode: .review, result: .forgot),
            ReviewLogEntry(wordId: "a", at: date(2026, 10, 8, 14), dayKey: today, mode: .learn, result: .learned),
        ]
        let result = StatsCalculator.summaries(plans: [plan], log: log)
        #expect(result == [DaySummary(dayKey: today, planSize: 4, learned: 2, reviewTarget: 2, reviewsAnswered: 2)])
        #expect(result[0].isCompleted)
    }

    @Test func totalsAndBreakdowns() throws {
        let catalog = try makeCatalog(ox3000: 8, ox5000: 4)
        let progress = progressMap([
            WordProgress(wordId: "w1", status: .review, box: 1), WordProgress(wordId: "w2", status: .mastered, box: 6),
            WordProgress(wordId: "w3", status: .learning), WordProgress(wordId: "w4", status: .known),
            WordProgress(wordId: "w1001", status: .review, box: 2),
        ])
        let totals = StatsCalculator.totals(catalog: catalog, progress: progress)
        #expect(totals.total == 12)
        #expect(totals.review == 2 && totals.mastered == 1 && totals.learning == 1 && totals.known == 1 && totals.new == 7)
        #expect(totals.learned == 3)
        let lists = StatsCalculator.byList(catalog: catalog, progress: progress)
        #expect(lists[.ox3000]?.total == 8 && lists[.ox5000]?.review == 1)
        let levels = StatsCalculator.byLevel(catalog: catalog, progress: progress)
        #expect(levels.values.map(\.total).reduce(0, +) == 12)
    }

    @Test func learnedPerDayCoversTheWindowOldestFirst() {
        let log = [
            ReviewLogEntry(wordId: "a", at: date(2026, 10, 8), dayKey: today, mode: .learn, result: .learned),
            ReviewLogEntry(wordId: "b", at: date(2026, 10, 8), dayKey: today, mode: .learn, result: .learned),
            ReviewLogEntry(wordId: "c", at: date(2026, 10, 6), dayKey: today.adding(days: -2), mode: .learn, result: .learned),
            ReviewLogEntry(wordId: "d", at: date(2026, 10, 8), dayKey: today, mode: .learn, result: .stillLearning),
            ReviewLogEntry(wordId: "e", at: date(2026, 10, 8), dayKey: today, mode: .review, result: .remembered),
        ]
        let counts = StatsCalculator.learnedPerDay(log: log, today: today, days: 5)
        #expect(counts.map(\.count) == [0, 0, 1, 0, 2])
        #expect(counts.first?.dayKey == today.adding(days: -4) && counts.last?.dayKey == today)
    }

    @Test func forecastPutsOverdueWordsOnToday() {
        let progress = progressMap([
            WordProgress(wordId: "a", status: .review, box: 1, dueDayKey: today.adding(days: -2)),
            WordProgress(wordId: "b", status: .review, box: 1, dueDayKey: today),
            WordProgress(wordId: "c", status: .review, box: 1, dueDayKey: today.adding(days: 1)),
            WordProgress(wordId: "d", status: .review, box: 1, dueDayKey: today.adding(days: 1)),
            WordProgress(wordId: "e", status: .review, box: 3, dueDayKey: today.adding(days: 10)),
            WordProgress(wordId: "f", status: .learning),
        ])
        #expect(StatsCalculator.reviewForecast(progress: progress, today: today, days: 3) == [2, 2, 0])
    }
}
