import Foundation
import StudyCore
import Testing

@testable import EnglishCards

@MainActor
@Suite struct StudyServiceTests {
    private func makeService(now: TestNow, repository: ProgressRepository = InMemoryProgressRepository()) throws -> StudyService {
        let engine = try StudyEngine(
            catalog: makeTestCatalog(), repository: repository, settings: StudySettings(), clock: testClock(),
            now: { now.value })
        return StudyService(engine: engine)
    }

    @Test func publishesTheStateAfterEveryAction() throws {
        let service = try makeService(now: TestNow(testDate(2026, 10, 8)))
        let first = try #require(service.currentWord)
        #expect(service.plan.totalCount == 60 && service.plan.learnedCount == 0)
        #expect(!service.canUndoLearn)

        service.perform(.learned)
        #expect(service.plan.learnedCount == 1)
        #expect(service.status(of: first.id) == .review)
        #expect(service.currentWord?.id != first.id)
        #expect(service.canUndoLearn)

        service.undoLearn()
        #expect(service.currentWord?.id == first.id)
        #expect(service.status(of: first.id) == .new)
        #expect(!service.canUndoLearn)
        #expect(service.lastError == nil)
    }

    @Test func reviewBadgeFollowsTheEngine() throws {
        let now = TestNow(testDate(2026, 10, 8))
        let service = try makeService(now: now)
        for _ in 0..<5 { service.perform(.learned) }
        #expect(service.reviewDueCount == 0)

        now.value = testDate(2026, 10, 9)
        #expect(service.refreshDay())
        #expect(service.reviewDueCount == 5)
        service.answer(.remembered)
        #expect(service.reviewDueCount == 4)
        #expect(service.reviewsAnsweredToday == 1)
        #expect(service.currentReviewWord != nil)
    }

    @Test func refreshingTheSameDayChangesNothing() throws {
        let now = TestNow(testDate(2026, 10, 8))
        let service = try makeService(now: now)
        service.perform(.learned)
        let plan = service.plan
        #expect(!service.refreshDay())
        #expect(service.plan == plan)
    }

    @Test func dayWatcherOpensTheNewDayRightAfterTheBoundary() async throws {
        // The clock is moved to one second before the next study day starts (04:00).
        let now = TestNow(testDate(2026, 10, 9, 3).addingTimeInterval(59 * 60 + 59))
        let service = try makeService(now: now)
        let firstDay = service.today
        service.startDayWatcher()
        defer { service.stopDayWatcher() }

        // Let the watcher read the clock first: it then sleeps ~1.3 s (one second to the boundary
        // plus a margin). Only afterwards the clock moves past 04:00.
        try await Task.sleep(for: .seconds(0.3))
        now.value = testDate(2026, 10, 9, 4).addingTimeInterval(1)
        try await Task.sleep(for: .seconds(2.0))
        #expect(service.today == firstDay.adding(days: 1))
    }

    @Test func newStudySettingsApplyToTheNextPlanOnly() throws {
        let now = TestNow(testDate(2026, 10, 8))
        let service = try makeService(now: now)
        var settings = service.studySettings
        settings.newWordsPerDay = 20
        service.apply(settings)
        #expect(service.plan.totalCount == 60)

        now.value = testDate(2026, 10, 9)
        service.refreshDay()
        #expect(service.plan.totalCount == 20)
    }

    @Test func changingTheStartHourReopensTheCorrectDay() throws {
        // 03:00 belongs to the previous study day with a 04:00 start, and to the new one with 02:00.
        let now = TestNow(testDate(2026, 10, 9, 3))
        let service = try makeService(now: now)
        #expect(service.today == DayKey(year: 2026, month: 10, day: 8))
        var settings = service.studySettings
        settings.dayStartHour = 2
        service.apply(settings)
        #expect(service.today == DayKey(year: 2026, month: 10, day: 9))
    }

    @Test func aStorageFailureIsReportedAndLeavesTheStateUntouched() throws {
        @MainActor final class FailingRepository: ProgressRepository {
            let base = InMemoryProgressRepository()
            var failCommits = false
            struct Failure: Error {}
            func allProgress() throws -> [String: WordProgress] { try base.allProgress() }
            func plan(for day: DayKey) throws -> DailyPlan? { try base.plan(for: day) }
            func allPlans() throws -> [DailyPlan] { try base.allPlans() }
            func log(on day: DayKey) throws -> [ReviewLogEntry] { try base.log(on: day) }
            func allLog() throws -> [ReviewLogEntry] { try base.allLog() }
            func commit(_ change: StateChange) throws {
                if failCommits { throw Failure() }
                try base.commit(change)
            }
            func eraseAll() throws { try base.eraseAll() }
            func replaceAll(progress: [WordProgress], plans: [DailyPlan], log: [ReviewLogEntry]) throws {
                try base.replaceAll(progress: progress, plans: plans, log: log)
            }
        }
        let repository = FailingRepository()
        let service = try makeService(now: TestNow(testDate(2026, 10, 8)), repository: repository)
        let before = service.plan
        repository.failCommits = true
        service.perform(.learned)
        #expect(service.lastError != nil)
        #expect(service.plan == before)
        #expect(service.progress.isEmpty)

        repository.failCommits = false
        service.perform(.learned)
        #expect(service.lastError == nil)
        #expect(service.plan.learnedCount == 1)
    }
}
