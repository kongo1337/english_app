import Foundation
import Testing
@testable import StudyCore

private struct FakeSettings: Codable, Equatable, Sendable { var n = 60 }

@MainActor
@Suite struct BackupTests {
    private func busyEngine() throws -> (StudyEngine, InMemoryProgressRepository, TestNow) {
        let now = TestNow(date(2026, 10, 8, 12))
        let repository = InMemoryProgressRepository()
        let engine = try makeEngine(catalog: makeCatalog(), repository: repository, now: now)
        for _ in 0..<5 { try engine.perform(.learned) }
        try engine.perform(.stillLearning)
        try engine.toggleFavorite(try #require(engine.plan.wordIds.last))
        return (engine, repository, now)
    }

    @Test func fileRoundTripsThroughJSON() throws {
        let (engine, _, now) = try busyEngine()
        let file = BackupFile(
            exportedAt: now.value, dictionaryVersion: 3, settings: FakeSettings(), payload: try engine.snapshot())
        let data = try file.encoded()
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"format\" : 1") && json.contains("\"dictionaryVersion\" : 3"))
        let decoded = try BackupFile<FakeSettings>.decode(data)
        #expect(decoded.payload == file.payload)
        #expect(decoded.settings == FakeSettings())
        #expect(!decoded.payload.log.isEmpty && !decoded.payload.plans.isEmpty)
    }

    @Test func restoreOnAnotherDeviceRecreatesTheState() throws {
        let (engine, _, now) = try busyEngine()
        let payload = try engine.snapshot()

        let fresh = try makeEngine(catalog: makeCatalog(), repository: InMemoryProgressRepository(), now: now)
        #expect(fresh.progress.values.allSatisfy { $0.status == .new })
        try fresh.restore(payload)
        #expect(fresh.progress == engine.progress)
        #expect(fresh.plan == engine.plan)
        #expect(fresh.phase == engine.phase)
        #expect(fresh.reviewQueue == engine.reviewQueue)
        #expect(!fresh.canUndoLearn, "undo history does not survive a restore")
    }

    @Test func restoreReplacesInsteadOfMerging() throws {
        let (engine, _, _) = try busyEngine()
        try engine.restore(BackupPayload())
        #expect(engine.progress.isEmpty)
        #expect(engine.plan.wordIds.count == 60, "a fresh plan is built for today")
        #expect(engine.plan.learnedCount == 0)
    }

    @Test func eraseAllStartsOver() throws {
        let (engine, repository, _) = try busyEngine()
        try engine.eraseAll()
        #expect(engine.progress.isEmpty)
        #expect(try repository.allLog().isEmpty)
        #expect(try repository.allPlans().count == 1, "only today's fresh plan remains")
        #expect(engine.plan.learnedCount == 0)
        #expect(engine.reviewDueCount == 0)
    }

    @Test func garbageAndFutureFormatsAreRejected() throws {
        #expect(throws: BackupError.unreadable) { try BackupFile<FakeSettings>.decode(Data("nope".utf8)) }
        #expect(throws: BackupError.unreadable) { try BackupFile<FakeSettings>.decode(Data("{\"format\":1}".utf8)) }
        #expect(throws: BackupError.unsupportedFormat(2)) {
            try BackupFile<FakeSettings>.decode(Data("{\"format\":2,\"extra\":true}".utf8))
        }
    }

    @Test func impossibleBoxesAreRejected() throws {
        let bad = BackupPayload(progress: [WordProgress(wordId: "w1", status: .review, box: 9)])
        let file = BackupFile(exportedAt: date(2026, 10, 8), dictionaryVersion: 1, settings: FakeSettings(), payload: bad)
        #expect(throws: BackupError.unreadable) { try BackupFile<FakeSettings>.decode(try file.encoded()) }
    }
}

@Suite struct ReminderPlannerTests {
    private let studyClock = testClockMoscow()
    private let today = DayKey(year: 2026, month: 10, day: 8)

    @Test func schedulesTodayAndTheNextSixDays() {
        let plans = ReminderPlanner.plan(
            now: date(2026, 10, 8, 9), hour: 19, minute: 0, clock: studyClock, today: today,
            newRemaining: 25, reviewForecast: [22, 35, 0, 4, 0, 0, 0])
        #expect(plans.count == 7)
        #expect(plans[0].fireDate == date(2026, 10, 8, 19))
        #expect(plans[0].body == "Сегодня ещё 25 новых слов и 22 повторения.")
        #expect(plans[1].body == "Ждёт новый набор слов и 35 повторений.")
        #expect(plans[2].body == "Новый набор слов уже ждёт.")
        #expect(plans[3].fireDate == date(2026, 10, 11, 19))
    }

    @Test func todayIsSkippedOnceThePlanIsDone() {
        let plans = ReminderPlanner.plan(
            now: date(2026, 10, 8, 9), hour: 19, minute: 0, clock: studyClock, today: today,
            newRemaining: 0, reviewForecast: [0, 3])
        #expect(plans.count == 6)
        #expect(plans[0].fireDate == date(2026, 10, 9, 19))
    }

    @Test func todayIsSkippedWhenTheTimeHasPassed() {
        let plans = ReminderPlanner.plan(
            now: date(2026, 10, 8, 20), hour: 19, minute: 30, clock: studyClock, today: today,
            newRemaining: 10, reviewForecast: [])
        #expect(plans.count == 6)
        #expect(plans[0].fireDate == date(2026, 10, 9, 19, 30))
    }

    @Test func onlyReviewsLeftToday() {
        let plans = ReminderPlanner.plan(
            now: date(2026, 10, 8, 9), hour: 19, minute: 15, clock: studyClock, today: today,
            newRemaining: 0, reviewForecast: [1])
        #expect(plans[0].body == "Сегодня ещё 1 повторение.")
    }

    @Test func plural() {
        #expect(ReminderTexts.body(newWords: 1, reviews: 0) == "Сегодня ещё 1 новое слово.")
        #expect(ReminderTexts.body(newWords: 3, reviews: 2) == "Сегодня ещё 3 новых слова и 2 повторения.")
    }
}

private func testClockMoscow() -> DayClock { clock(zone: "Europe/Moscow") }
