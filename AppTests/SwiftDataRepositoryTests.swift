import Foundation
import StudyCore
import SwiftData
import Testing

@testable import EnglishCards

private let day = DayKey(year: 2026, month: 10, day: 8)

@MainActor
@Suite struct SwiftDataRepositoryTests {
    private func makeRepository() throws -> SwiftDataProgressRepository {
        SwiftDataProgressRepository(container: try Persistence.makeContainer(inMemory: true))
    }

    private let sample = WordProgress(
        wordId: "w1", status: .review, box: 3, dueDayKey: DayKey(year: 2026, month: 10, day: 15),
        firstSeenAt: testDate(2026, 10, 1), lastSeenAt: testDate(2026, 10, 8), timesSeen: 5, lapses: 2,
        isFavorite: true)

    @Test func startsEmpty() throws {
        let repository = try makeRepository()
        #expect(try repository.allProgress().isEmpty)
        #expect(try repository.plan(for: day) == nil)
        #expect(try repository.allPlans().isEmpty)
        #expect(try repository.allLog().isEmpty)
    }

    @Test func progressRoundTripsEveryField() throws {
        let repository = try makeRepository()
        try repository.commit(StateChange(progress: [sample]))
        #expect(try repository.allProgress() == ["w1": sample])
    }

    @Test func committingTheSameWordUpdatesTheRow() throws {
        let repository = try makeRepository()
        try repository.commit(StateChange(progress: [sample]))
        var changed = sample
        changed.status = .mastered
        changed.timesSeen = 9
        try repository.commit(StateChange(progress: [changed]))
        #expect(try repository.allProgress() == ["w1": changed])
    }

    @Test func removedProgressIsDeleted() throws {
        let repository = try makeRepository()
        try repository.commit(StateChange(progress: [sample, WordProgress(wordId: "w2", status: .learning)]))
        try repository.commit(StateChange(removedProgress: ["w1"]))
        #expect(try repository.allProgress().keys.sorted() == ["w2"])
    }

    @Test func planRoundTripsAndKeepsTheQueueOrder() throws {
        let repository = try makeRepository()
        let plan = DailyPlan(
            dayKey: day, wordIds: ["a", "b", "c", "d"], queue: ["c", "a", "d"], learnedIds: ["b"],
            seenIds: ["a", "c"], extraBatches: 2, reviewTarget: 7)
        try repository.commit(StateChange(plan: plan))
        #expect(try repository.plan(for: day) == plan)
        #expect(try repository.plan(for: day.adding(days: 1)) == nil)

        var updated = plan
        updated.queue = ["d"]
        try repository.commit(StateChange(plan: updated))
        #expect(try repository.allPlans() == [updated])
    }

    @Test func logIsAppendedFilteredByDayAndRemovable() throws {
        let repository = try makeRepository()
        let first = ReviewLogEntry(wordId: "a", at: testDate(2026, 10, 8, 10), dayKey: day, mode: .learn, result: .learned)
        let second = ReviewLogEntry(wordId: "b", at: testDate(2026, 10, 8, 11), dayKey: day, mode: .review, result: .forgot)
        let other = ReviewLogEntry(wordId: "a", at: testDate(2026, 10, 9, 10), dayKey: day.adding(days: 1), mode: .review, result: .remembered)
        try repository.commit(StateChange(appendedLog: [first, second, other]))

        #expect(try repository.log(on: day) == [first, second])
        #expect(try repository.allLog() == [first, second, other])

        try repository.commit(StateChange(removedLog: [second.key]))
        #expect(try repository.allLog() == [first, other])
    }

    @Test func oneCommitAppliesEverythingTogether() throws {
        let repository = try makeRepository()
        let entry = ReviewLogEntry(wordId: "w1", at: testDate(2026, 10, 8), dayKey: day, mode: .learn, result: .learned)
        try repository.commit(StateChange(
            progress: [sample], plan: DailyPlan(dayKey: day, wordIds: ["w1"]), appendedLog: [entry]))
        #expect(try repository.allProgress().count == 1)
        #expect(try repository.allPlans().count == 1)
        #expect(try repository.allLog() == [entry])
    }

    @Test func eraseAllRemovesEverything() throws {
        let repository = try makeRepository()
        try repository.commit(StateChange(
            progress: [sample], plan: DailyPlan(dayKey: day, wordIds: ["w1"]),
            appendedLog: [ReviewLogEntry(wordId: "w1", at: testDate(2026, 10, 8), dayKey: day, mode: .learn, result: .learned)]))
        try repository.eraseAll()
        #expect(try repository.allProgress().isEmpty)
        #expect(try repository.allPlans().isEmpty)
        #expect(try repository.allLog().isEmpty)
    }

    @Test func replaceAllSwapsTheWholeState() throws {
        let repository = try makeRepository()
        try repository.commit(StateChange(progress: [WordProgress(wordId: "old", status: .known)]))
        let plan = DailyPlan(dayKey: day, wordIds: ["w1"])
        try repository.replaceAll(progress: [sample], plans: [plan], log: [])
        #expect(try repository.allProgress() == ["w1": sample])
        #expect(try repository.allPlans() == [plan])
    }
}
