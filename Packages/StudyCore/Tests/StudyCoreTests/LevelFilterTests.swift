import Foundation
import Testing
@testable import StudyCore

@Suite struct LevelFilterSettingsTests {
    @Test func allowsChecksTheListAndTheMinimumLevel() {
        let a1 = testWord(1, list: .ox3000, level: .a1)
        let b1 = testWord(2, list: .ox3000, level: .b1)
        let c1 = testWord(3, list: .ox5000, level: .c1)
        var settings = StudySettings(minLevel: .b1)
        #expect(!settings.allows(a1) && settings.allows(b1) && settings.allows(c1))
        settings.enabledLists = [.ox5000]
        #expect(!settings.allows(b1) && settings.allows(c1))
    }

    @Test func settingsFromAnOlderVersionKeepEverythingElse() throws {
        // Written before `minLevel` existed.
        let json = """
            {"newWordsPerDay":35,"carryoverBuffer":10,"enabledLists":["ox5000"],"order":"random",
             "seed":12345,"dayStartHour":5,"extraBatchSize":20}
            """
        let settings = try JSONDecoder().decode(StudySettings.self, from: Data(json.utf8))
        #expect(settings.newWordsPerDay == 35 && settings.carryoverBuffer == 10)
        #expect(settings.enabledLists == [.ox5000] && settings.order == .random)
        #expect(settings.seed == 12345 && settings.dayStartHour == 5 && settings.extraBatchSize == 20)
        #expect(settings.minLevel == .a1, "a missing level means everything")
        #expect(settings.reviewLimit == nil)
    }

    @Test func settingsRoundTrip() throws {
        let original = StudySettings(
            newWordsPerDay: 40, enabledLists: [.ox3000], reviewLimit: 100, seed: 99, minLevel: .b2)
        let decoded = try JSONDecoder().decode(StudySettings.self, from: JSONEncoder().encode(original))
        #expect(decoded == original)
    }

    @Test func newWordsAndCarryoverRespectTheMinimumLevel() throws {
        let catalog = try makeCatalog(ox3000: 100, ox5000: 50)
        var progress: [String: WordProgress] = [:]
        // One still-learning A1 word and one still-learning B2 word.
        let a1 = try #require(catalog.words.first { $0.cefr == .a1 })
        let b2 = try #require(catalog.words.first { $0.cefr == .b2 })
        progress[a1.id] = WordProgress(wordId: a1.id, status: .learning, lastSeenAt: date(2026, 10, 1))
        progress[b2.id] = WordProgress(wordId: b2.id, status: .learning, lastSeenAt: date(2026, 10, 2))

        let settings = StudySettings(minLevel: .b1)
        let plan = DailyPlanBuilder.build(
            dayKey: DayKey(year: 2026, month: 10, day: 8), catalog: catalog, progress: progress, settings: settings)
        let words = plan.wordIds.compactMap(catalog.word(id:))
        #expect(words.count == 60 + 1 - 0 || words.count == 61, "one carried word plus 60 new ones")
        #expect(words.allSatisfy { $0.cefr >= .b1 }, "no A1/A2 word in the plan")
        #expect(plan.wordIds.first == b2.id, "the allowed carry-over word goes first")
        #expect(!plan.wordIds.contains(a1.id), "the A1 word waits outside the filter")
        #expect(progress[a1.id]?.status == .learning, "its progress is untouched")
    }
}

@MainActor
@Suite struct LevelFilterEngineTests {
    let start = date(2026, 10, 8, 12)

    @Test func raisingTheLevelReplacesTheWordsOfTodayRightAway() throws {
        let now = TestNow(start)
        let engine = try makeEngine(catalog: makeCatalog(ox3000: 200, ox5000: 100), now: now)
        #expect(engine.plan.wordIds.contains { engine.catalog.word(id: $0)?.cefr == .a1 })

        engine.settings.minLevel = .b1
        try engine.applyFilterChange()

        let words = engine.plan.wordIds.compactMap(engine.catalog.word(id:))
        #expect(words.count == 60, "the day keeps its size")
        #expect(words.allSatisfy { $0.cefr >= .b1 })
        #expect(engine.plan.queue == engine.plan.wordIds)
        let current = try #require(engine.currentWord)
        #expect(current.cefr >= .b1)
    }

    @Test func wordsLearnedTodayStayAndKeepCounting() throws {
        let now = TestNow(start)
        let repository = InMemoryProgressRepository()
        let engine = try makeEngine(catalog: makeCatalog(ox3000: 200, ox5000: 100), repository: repository, now: now)
        var learned: [String] = []
        for _ in 0..<5 {
            learned.append(try #require(engine.plan.currentWordId))
            try engine.perform(.learned)
        }
        #expect(learned.count == 5)

        engine.settings.minLevel = .b2
        try engine.applyFilterChange()

        #expect(engine.plan.learnedCount == 5, "the day's progress is not lost")
        #expect(learned.allSatisfy { engine.plan.wordIds.contains($0) })
        #expect(engine.plan.wordIds.count == 60, "5 learned + 55 new = the usual 60")
        let queueWords = engine.plan.queue.compactMap(engine.catalog.word(id:))
        #expect(queueWords.count == 55 && queueWords.allSatisfy { $0.cefr >= .b2 })
        #expect(!engine.canUndoLearn, "the plan changed, older snapshots are void")

        // Persisted: a new engine on the same storage sees the same plan.
        let reopened = try makeEngine(catalog: engine.catalog, repository: repository, now: now)
        #expect(reopened.plan == engine.plan)
    }

    @Test func switchingADictionaryOffRemovesItsWords() throws {
        let now = TestNow(start)
        let engine = try makeEngine(catalog: makeCatalog(ox3000: 100, ox5000: 100), now: now)
        engine.settings.enabledLists = [.ox5000]
        try engine.applyFilterChange()
        let words = engine.plan.wordIds.compactMap(engine.catalog.word(id:))
        #expect(words.count == 60 && words.allSatisfy { $0.list == .ox5000 })
    }

    @Test func switchingBackBringsTheWordsBackTomorrow() throws {
        let now = TestNow(start)
        let engine = try makeEngine(catalog: makeCatalog(), now: now)
        engine.settings.minLevel = .b2
        try engine.applyFilterChange()
        engine.settings.minLevel = .a1
        try engine.applyFilterChange()
        let levels = Set(engine.plan.wordIds.compactMap(engine.catalog.word(id:)).map(\.cefr))
        #expect(levels.contains(.a1), "lowering the level lets the easy words in again")
    }

    @Test func aStillLearningWordOutsideTheFilterLeavesTodayButKeepsItsProgress() throws {
        let now = TestNow(start)
        let engine = try makeEngine(catalog: makeCatalog(ox3000: 200, ox5000: 50), now: now)
        let first = try #require(engine.currentWord)
        #expect(first.cefr == .a1)
        try engine.perform(.stillLearning)

        engine.settings.minLevel = .b1
        try engine.applyFilterChange()

        #expect(!engine.plan.wordIds.contains(first.id))
        #expect(engine.progress[first.id]?.status == .learning)
    }

    @Test func nothingChangesWhenTheFilterDoesNotMatterToThePlan() throws {
        let now = TestNow(start)
        let engine = try makeEngine(catalog: makeCatalog(ox3000: 100, ox5000: 50), now: now)
        let before = engine.plan
        try engine.applyFilterChange()
        #expect(engine.plan == before)
    }

    @Test func nothingLeftToLearnShowsTheAllDoneState() throws {
        let now = TestNow(start)
        let engine = try makeEngine(catalog: makeCatalog(ox3000: 20, ox5000: 0), now: now)
        engine.settings.minLevel = .c1
        try engine.applyFilterChange()
        #expect(engine.plan.wordIds.isEmpty)
        #expect(engine.phase == .allDone)
    }
}
