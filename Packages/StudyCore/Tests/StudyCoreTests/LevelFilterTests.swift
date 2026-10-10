import Foundation
import Testing
@testable import StudyCore

@Suite struct LevelFilterSettingsTests {
    @Test func allowsChecksTheListAndTheMinimumLevel() {
        let a1 = testWord(1, list: .ox3000, level: .a1)
        let b1 = testWord(2, list: .ox3000, level: .b1)
        let c1 = testWord(3, list: .ox5000, level: .c1)
        var settings = StudySettings(levels: [.b1, .b2, .c1])
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
        #expect(settings.levels == Set(CEFRLevel.allCases), "a missing level choice means every level")
        #expect(settings.reviewLimit == nil)
    }

    @Test func aSavedMinimumLevelFromTheEarlierVersionBecomesASetOfLevels() throws {
        let json = #"{"newWordsPerDay":60,"minLevel":"B1","seed":7}"#
        let settings = try JSONDecoder().decode(StudySettings.self, from: Data(json.utf8))
        #expect(settings.levels == [.b1, .b2, .c1])
        #expect(settings.seed == 7)
        let saved = String(data: try JSONEncoder().encode(settings), encoding: .utf8) ?? ""
        #expect(!saved.contains("minLevel"), "only the new key is written")
    }

    @Test func settingsRoundTrip() throws {
        let original = StudySettings(
            newWordsPerDay: 40, enabledLists: [.ox3000], reviewLimit: 100, seed: 99, levels: [.b2, .c1])
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

        let settings = StudySettings(levels: [.b1, .b2, .c1])
        let plan = DailyPlanBuilder.build(
            dayKey: DayKey(year: 2026, month: 10, day: 8), catalog: catalog, progress: progress, settings: settings)
        let words = plan.wordIds.compactMap(catalog.word(id:))
        #expect(words.count == 60 + 1 - 0 || words.count == 61, "one carried word plus 60 new ones")
        #expect(words.allSatisfy { [CEFRLevel.b1, .b2, .c1].contains($0.cefr) }, "no A1/A2 word in the plan")
        #expect(plan.wordIds.first == b2.id, "the allowed carry-over word goes first")
        #expect(!plan.wordIds.contains(a1.id), "the A1 word waits outside the filter")
        #expect(progress[a1.id]?.status == .learning, "its progress is untouched")
    }
}

@Suite struct LevelMixingTests {
    @Test func chosenLevelsAreMixedNotListedByLevel() throws {
        let catalog = try makeCatalog(ox3000: 200, ox5000: 0)
        var settings = StudySettings(levels: [.a1, .b2])
        settings.order = .byLevel
        let words = DailyPlanBuilder.orderedNewWords(catalog: catalog, progress: [:], settings: settings)
        #expect(Set(words.map(\.cefr)) == [.a1, .b2])
        // In a list ordered by level all A1 words would come before every B2 word.
        let firstB2 = try #require(words.firstIndex { $0.cefr == .b2 })
        let lastA1 = try #require(words.lastIndex { $0.cefr == .a1 })
        #expect(firstB2 < lastA1, "A1 and B2 words are interleaved")
        let leading = words.prefix(40).map(\.cefr)
        #expect(leading.contains(.a1) && leading.contains(.b2), "both levels show up early in the plan")
    }

    @Test func theMixIsStableBetweenCalls() throws {
        let catalog = try makeCatalog(ox3000: 200, ox5000: 0)
        let settings = StudySettings(levels: [.a2, .b1])
        let first = DailyPlanBuilder.orderedNewWords(catalog: catalog, progress: [:], settings: settings).map(\.id)
        let second = DailyPlanBuilder.orderedNewWords(catalog: catalog, progress: [:], settings: settings).map(\.id)
        #expect(first == second)
    }

    @Test func withEveryLevelChosenTheOldOrderByLevelRemains() throws {
        let catalog = try makeCatalog(ox3000: 200, ox5000: 0)
        let words = DailyPlanBuilder.orderedNewWords(catalog: catalog, progress: [:], settings: StudySettings())
        let levels = words.map(\.cefr)
        #expect(levels == levels.sorted(), "A1 first, then A2, B1, B2")
    }

    @Test func alphabeticalOrderIsKeptWhateverLevelsAreChosen() throws {
        let catalog = try makeCatalog(ox3000: 100, ox5000: 0)
        var settings = StudySettings(levels: [.a1, .b2])
        settings.order = .alphabetical
        let lemmas = DailyPlanBuilder.orderedNewWords(catalog: catalog, progress: [:], settings: settings)
            .map { $0.lemma.lowercased() }
        #expect(lemmas == lemmas.sorted())
    }
}

@MainActor
@Suite struct LevelFilterEngineTests {
    let start = date(2026, 10, 8, 12)

    @Test func raisingTheLevelReplacesTheWordsOfTodayRightAway() throws {
        let now = TestNow(start)
        let engine = try makeEngine(catalog: makeCatalog(ox3000: 200, ox5000: 100), now: now)
        #expect(engine.plan.wordIds.contains { engine.catalog.word(id: $0)?.cefr == .a1 })

        engine.settings.levels = [.b1, .b2, .c1]
        try engine.applyFilterChange()

        let words = engine.plan.wordIds.compactMap(engine.catalog.word(id:))
        #expect(words.count == 60, "the day keeps its size")
        #expect(words.allSatisfy { [CEFRLevel.b1, .b2, .c1].contains($0.cefr) })
        #expect(engine.plan.queue == engine.plan.wordIds)
        let current = try #require(engine.currentWord)
        #expect([CEFRLevel.b1, .b2, .c1].contains(current.cefr))
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

        engine.settings.levels = [.b2, .c1]
        try engine.applyFilterChange()

        #expect(engine.plan.learnedCount == 5, "the day's progress is not lost")
        #expect(learned.allSatisfy { engine.plan.wordIds.contains($0) })
        #expect(engine.plan.wordIds.count == 60, "5 learned + 55 new = the usual 60")
        let queueWords = engine.plan.queue.compactMap(engine.catalog.word(id:))
        #expect(queueWords.count == 55 && queueWords.allSatisfy { [CEFRLevel.b2, .c1].contains($0.cefr) })
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

    @Test func changingTheLevelCombinationReplacesTheWords() throws {
        let now = TestNow(start)
        let engine = try makeEngine(catalog: makeCatalog(ox3000: 400, ox5000: 0), now: now)

        engine.settings.levels = [.b1, .b2]
        try engine.applyFilterChange()
        let first = Set(engine.plan.wordIds.compactMap(engine.catalog.word(id:)).map(\.cefr))
        #expect(first == [.b1, .b2])

        engine.settings.levels = [.a1, .a2]
        try engine.applyFilterChange()
        let second = Set(engine.plan.wordIds.compactMap(engine.catalog.word(id:)).map(\.cefr))
        #expect(second == [.a1, .a2], "the plan switched to the other levels")
        #expect(engine.plan.wordIds.count == 60)
    }

    @Test func switchingBackBringsTheWordsBackTomorrow() throws {
        let now = TestNow(start)
        let engine = try makeEngine(catalog: makeCatalog(), now: now)
        engine.settings.levels = [.b2, .c1]
        try engine.applyFilterChange()
        engine.settings.levels = Set(CEFRLevel.allCases)
        try engine.applyFilterChange()
        let levels = Set(engine.plan.wordIds.compactMap(engine.catalog.word(id:)).map(\.cefr))
        #expect(levels.contains(.a1), "choosing every level again lets the easy words in")
    }

    @Test func aStillLearningWordOutsideTheFilterLeavesTodayButKeepsItsProgress() throws {
        let now = TestNow(start)
        let engine = try makeEngine(catalog: makeCatalog(ox3000: 200, ox5000: 50), now: now)
        let first = try #require(engine.currentWord)
        #expect(first.cefr == .a1)
        try engine.perform(.stillLearning)

        engine.settings.levels = [.b1, .b2, .c1]
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
        engine.settings.levels = [.c1]
        try engine.applyFilterChange()
        #expect(engine.plan.wordIds.isEmpty)
        #expect(engine.phase == .allDone)
    }
}
