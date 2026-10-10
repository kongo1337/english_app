import Foundation
import Testing
@testable import StudyCore

private let day = DayKey(year: 2026, month: 10, day: 8)

private func learning(_ id: String, seen: Date? = nil) -> WordProgress {
    WordProgress(wordId: id, status: .learning, lastSeenAt: seen, timesSeen: 1)
}

@Suite struct DailyPlanBuilderTests {
    let settings = StudySettings()  // N = 60, B = 20

    @Test func firstDayHasSixtyNewWordsInStudyOrder() throws {
        let catalog = try makeCatalog(ox3000: 100, ox5000: 50)
        let plan = DailyPlanBuilder.build(dayKey: day, catalog: catalog, progress: [:], settings: settings)
        #expect(plan.wordIds.count == 60)
        #expect(plan.queue == plan.wordIds)
        #expect(plan.learnedIds.isEmpty && plan.seenIds.isEmpty)
        let words = plan.wordIds.compactMap(catalog.word(id:))
        // Oxford 3000 comes first and levels never go down inside a list.
        #expect(words.allSatisfy { $0.list == .ox3000 })
        #expect(words.map(\.cefr) == words.map(\.cefr).sorted())
    }

    @Test func carryoverComesFirstOldestFirst() throws {
        let catalog = try makeCatalog()
        let carried = [
            learning("w10", seen: date(2026, 10, 7)), learning("w11", seen: date(2026, 10, 5)),
            learning("w12", seen: date(2026, 10, 6)), learning("w13"), learning("w14", seen: date(2026, 10, 7)),
        ]
        let plan = DailyPlanBuilder.build(
            dayKey: day, catalog: catalog, progress: progressMap(carried), settings: settings)
        #expect(plan.wordIds.count == 65)
        #expect(Array(plan.wordIds.prefix(5)) == ["w13", "w11", "w12", "w10", "w14"])
        #expect(Set(plan.wordIds).count == 65)
    }

    @Test func carryoverShrinksTheNewWordsAndStopsAtZero() throws {
        let catalog = try makeCatalog(ox3000: 300, ox5000: 100)
        let settings = StudySettings()
        for (carry, expectedNew) in [(0, 60), (5, 60), (20, 60), (30, 50), (79, 1), (80, 0), (100, 0)] {
            let items = (0..<carry).map { learning("w\($0 + 1)") }
            let plan = DailyPlanBuilder.build(
                dayKey: day, catalog: catalog, progress: progressMap(items), settings: settings)
            #expect(plan.wordIds.count == carry + expectedNew, "carryover \(carry)")
        }
    }

    @Test func neverOffersFinishedWordsAsNew() throws {
        let catalog = try makeCatalog(ox3000: 100, ox5000: 0)
        let finished = (1...40).map { index -> WordProgress in
            let status: WordStatus = [.review, .mastered, .known, .review][index % 4]
            return WordProgress(wordId: "w\(index)", status: status, box: 1)
        }
        let plan = DailyPlanBuilder.build(
            dayKey: day, catalog: catalog, progress: progressMap(finished), settings: settings)
        #expect(plan.wordIds.count == 60)
        #expect(Set(plan.wordIds).isDisjoint(with: Set(finished.map(\.wordId))))
    }

    @Test func disabledListGivesNoWordsAtAll() throws {
        let catalog = try makeCatalog(ox3000: 100, ox5000: 50)
        var settings = StudySettings()
        settings.enabledLists = [.ox5000]
        // w5 belongs to the disabled Oxford 3000 and was already started: it waits, with its
        // progress, until the dictionary is switched on again.
        let plan = DailyPlanBuilder.build(
            dayKey: day, catalog: catalog, progress: progressMap([learning("w5")]), settings: settings)
        #expect(!plan.wordIds.contains("w5"))
        #expect(plan.wordIds.allSatisfy { catalog.word(id: $0)?.list == .ox5000 })
        #expect(plan.wordIds.count == 50)
    }

    @Test func exhaustedListsLeaveOnlyCarryover() throws {
        let catalog = try makeCatalog(ox3000: 10, ox5000: 0)
        let all = (1...10).map { WordProgress(wordId: "w\($0)", status: $0 <= 3 ? .learning : .known) }
        let plan = DailyPlanBuilder.build(dayKey: day, catalog: catalog, progress: progressMap(all), settings: settings)
        #expect(Set(plan.wordIds) == ["w1", "w2", "w3"])
    }

    @Test func ignoresProgressOfWordsRemovedFromTheDictionary() throws {
        let catalog = try makeCatalog(ox3000: 10, ox5000: 0)
        let plan = DailyPlanBuilder.build(
            dayKey: day, catalog: catalog, progress: progressMap([learning("gone")]), settings: settings)
        #expect(!plan.wordIds.contains("gone"))
    }

    @Test func orderModes() throws {
        let catalog = try makeCatalog(ox3000: 60, ox5000: 60)
        var settings = StudySettings()
        settings.newWordsPerDay = 120

        settings.order = .alphabetical
        let alphabetical = DailyPlanBuilder.orderedNewWords(catalog: catalog, progress: [:], settings: settings)
        #expect(alphabetical.map { $0.lemma.lowercased() } == alphabetical.map { $0.lemma.lowercased() }.sorted())

        settings.order = .random
        let random = DailyPlanBuilder.orderedNewWords(catalog: catalog, progress: [:], settings: settings)
        #expect(random.map(\.id) != alphabetical.map(\.id))
        #expect(Set(random.map(\.id)) == Set(alphabetical.map(\.id)))
        // Not grouped by list: both lists appear within the first dozen.
        #expect(Set(random.prefix(12).map(\.list)).count == 2)
    }

    @Test func orderIsStableForTheSameSeedAndChangesWithTheSeed() throws {
        let catalog = try makeCatalog()
        var a = StudySettings(); a.seed = 1
        var b = StudySettings(); b.seed = 2
        let first = DailyPlanBuilder.orderedNewWords(catalog: catalog, progress: [:], settings: a).map(\.id)
        let again = DailyPlanBuilder.orderedNewWords(catalog: catalog, progress: [:], settings: a).map(\.id)
        let other = DailyPlanBuilder.orderedNewWords(catalog: catalog, progress: [:], settings: b).map(\.id)
        #expect(first == again)
        #expect(first != other)
    }

    @Test func orderDoesNotReshuffleWhenOtherWordsAreLearned() throws {
        let catalog = try makeCatalog()
        let settings = StudySettings()
        let before = DailyPlanBuilder.orderedNewWords(catalog: catalog, progress: [:], settings: settings).map(\.id)
        let learned = progressMap(before.prefix(10).map { WordProgress(wordId: $0, status: .review, box: 1) })
        let after = DailyPlanBuilder.orderedNewWords(catalog: catalog, progress: learned, settings: settings).map(\.id)
        #expect(after == Array(before.dropFirst(10)))
    }

    @Test func extraWordsContinueAfterTheCurrentPlan() throws {
        let catalog = try makeCatalog()
        let settings = StudySettings()
        let plan = DailyPlanBuilder.build(dayKey: day, catalog: catalog, progress: [:], settings: settings)
        let extra = DailyPlanBuilder.extraWords(plan: plan, catalog: catalog, progress: [:], settings: settings)
        #expect(extra.count == 10)
        #expect(Set(extra).isDisjoint(with: Set(plan.wordIds)))
        let all = DailyPlanBuilder.orderedNewWords(catalog: catalog, progress: [:], settings: settings).map(\.id)
        #expect(extra == Array(all[60..<70]))
    }
}
