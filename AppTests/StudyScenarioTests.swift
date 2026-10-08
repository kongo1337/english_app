import Foundation
import StudyCore
import SwiftData
import Testing

@testable import EnglishCards

/// The same scripted study sessions run against the in-memory and the SwiftData storage
/// must leave identical state behind.
@MainActor
@Suite struct StudyScenarioTests {
    /// Three study days with a mix of every kind of action.
    private func playScript(on engine: StudyEngine, now: TestNow) throws {
        // Day 1
        for _ in 0..<6 { try engine.perform(.learned) }
        try engine.perform(.learned)
        try engine.perform(.stillLearning)
        try engine.perform(.known)
        try engine.perform(.learned)
        try engine.undoLearn()
        try engine.perform(.learned)
        try engine.toggleFavorite("w5")
        try engine.addToToday("w100")
        _ = try engine.addMoreWords()

        // Day 2
        now.value = testDate(2026, 10, 9)
        try engine.refreshDay()
        try engine.perform(.learned)
        try engine.perform(.stillLearning)
        for _ in 0..<3 { try engine.answer(.remembered) }
        try engine.answer(.forgot)
        try engine.undoReview()
        try engine.answer(.forgot)
        try engine.markKnown("w30")
        try engine.returnToLearning("w31")
        try engine.reset("w1")

        // Day 3
        now.value = testDate(2026, 10, 10)
        try engine.refreshDay()
        try engine.continueRound()
        try engine.finishForToday()
    }

    private func ordered(_ log: [ReviewLogEntry]) -> [String] {
        log.map { "\($0.at.timeIntervalSince1970)|\($0.wordId)|\($0.mode.rawValue)|\($0.result.rawValue)" }.sorted()
    }

    private func makeEngine(repository: ProgressRepository, now: TestNow, catalog: WordCatalog) throws -> StudyEngine {
        try StudyEngine(
            catalog: catalog, repository: repository, settings: StudySettings(), clock: testClock(), now: { now.value })
    }

    @Test func swiftDataStorageMatchesInMemoryStorage() throws {
        let catalog = try makeTestCatalog()

        let memory = InMemoryProgressRepository()
        let memoryNow = TestNow(testDate(2026, 10, 8))
        try playScript(on: makeEngine(repository: memory, now: memoryNow, catalog: catalog), now: memoryNow)

        let disk = SwiftDataProgressRepository(container: try Persistence.makeContainer(inMemory: true))
        let diskNow = TestNow(testDate(2026, 10, 8))
        try playScript(on: makeEngine(repository: disk, now: diskNow, catalog: catalog), now: diskNow)

        #expect(try disk.allProgress() == memory.allProgress())
        #expect(try disk.allPlans() == memory.allPlans())
        // Several entries share one timestamp (the test clock is frozen), so compare without relying on order.
        #expect(try ordered(disk.allLog()) == ordered(memory.allLog()))
        #expect(try !disk.allLog().isEmpty)
    }

    @Test func stateSurvivesRestartingTheApp() throws {
        let catalog = try makeTestCatalog()
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("progress.store")
        let now = TestNow(testDate(2026, 10, 8))

        let expectedPlan: DailyPlan
        let expectedProgress: [String: WordProgress]
        do {
            let container = try Persistence.makeContainer(url: url)
            let engine = try makeEngine(repository: SwiftDataProgressRepository(container: container), now: now, catalog: catalog)
            try engine.perform(.learned)
            try engine.perform(.stillLearning)
            try engine.perform(.known)
            expectedPlan = engine.plan
            expectedProgress = engine.progress
        }

        // A brand-new container on the same file: the "restarted" app.
        let reopened = try Persistence.makeContainer(url: url)
        let engine = try makeEngine(repository: SwiftDataProgressRepository(container: reopened), now: now, catalog: catalog)
        #expect(engine.plan == expectedPlan)
        #expect(engine.progress == expectedProgress)
        #expect(engine.plan.learnedCount == 1)
        #expect(engine.phase == .card(wordId: engine.plan.queue[0]))
    }
}
