import Foundation
import Testing
@testable import StudyCore

@Suite struct WordFilterTests {
    private func progress(_ id: String, _ status: WordStatus, lapses: Int = 0, favorite: Bool = false,
                          seen: Date? = nil) -> WordProgress {
        WordProgress(wordId: id, status: status, lastSeenAt: seen, lapses: lapses, isFavorite: favorite)
    }

    @Test func emptyFilterKeepsEverythingInDictionaryOrder() throws {
        let catalog = try makeCatalog(ox3000: 20, ox5000: 10)
        let result = WordFilter().apply(to: catalog, progress: [:])
        #expect(result.map(\.id) == catalog.words.map(\.id))
        #expect(!WordFilter().isActive)
    }

    @Test func listAndLevelRestrictTogether() throws {
        let catalog = try makeCatalog(ox3000: 40, ox5000: 20)
        var filter = WordFilter(list: .ox3000, levels: [.a1])
        var result = filter.apply(to: catalog, progress: [:])
        #expect(!result.isEmpty)
        #expect(result.allSatisfy { $0.list == .ox3000 && $0.cefr == .a1 })
        filter.levels = [.c1]
        result = filter.apply(to: catalog, progress: [:])
        #expect(result.isEmpty, "the Oxford 3000 has no C1 words")
    }

    @Test func statusesAreAlternatives() throws {
        let catalog = try makeCatalog(ox3000: 10, ox5000: 0)
        let state = [
            "w1": progress("w1", .learning), "w2": progress("w2", .review), "w3": progress("w3", .known),
        ]
        let learningOrReview = WordFilter(statuses: [.learning, .review]).apply(to: catalog, progress: state)
        #expect(Set(learningOrReview.map(\.id)) == ["w1", "w2"])
        let new = WordFilter(statuses: [.new]).apply(to: catalog, progress: state)
        #expect(new.count == 7, "words without progress count as new")
    }

    @Test func hardAndFavoriteCutAcrossStatuses() throws {
        let catalog = try makeCatalog(ox3000: 10, ox5000: 0)
        let state = [
            "w1": progress("w1", .learning, lapses: 3),
            "w2": progress("w2", .review, lapses: 2),
            "w3": progress("w3", .review, favorite: true),
            "w4": progress("w4", .known, lapses: 5, favorite: true),
        ]
        #expect(Set(WordFilter(statuses: [.hard]).apply(to: catalog, progress: state).map(\.id)) == ["w1", "w4"])
        #expect(Set(WordFilter(statuses: [.favorite]).apply(to: catalog, progress: state).map(\.id)) == ["w3", "w4"])
        #expect(WordFilter(statuses: [.favorite, .hard]).apply(to: catalog, progress: state).count == 3)
    }

    @Test func searchRanksByRelevanceAndStillAppliesFilters() throws {
        let catalog = try makeCatalog(ox3000: 30, ox5000: 0)
        let found = WordFilter(query: "word1").apply(to: catalog, progress: [:])
        #expect(found.first?.id == "w1", "the exact match comes first")
        #expect(found.count == 11, "word1, word10…word19")
        let learning = WordFilter(query: "word1", statuses: [.learning])
            .apply(to: catalog, progress: ["w12": progress("w12", .learning)])
        #expect(learning.map(\.id) == ["w12"])
        #expect(WordFilter(query: "   ").apply(to: catalog, progress: [:]).count == 30, "blank query = no search")
    }

    @Test func sortAlphabeticalAndRecent() throws {
        let catalog = try makeCatalog(ox3000: 5, ox5000: 0)
        let alphabetical = WordFilter(sort: .alphabetical).apply(to: catalog, progress: [:])
        #expect(alphabetical.map(\.lemma) == ["word1", "word2", "word3", "word4", "word5"])

        let state = [
            "w2": progress("w2", .review, seen: date(2026, 10, 1)),
            "w4": progress("w4", .review, seen: date(2026, 10, 5)),
        ]
        let recent = WordFilter(sort: .recent).apply(to: catalog, progress: state)
        #expect(recent.map(\.id) == ["w4", "w2", "w1", "w3", "w5"])
    }

    @Test func realDictionaryFilteringIsFast() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("App/Resources/words.json")
        let catalog = try WordCatalog.load(contentsOf: url)
        let start = Date()
        let result = WordFilter(levels: [.b1], statuses: [.new]).apply(to: catalog, progress: [:])
        #expect(!result.isEmpty)
        #expect(Date().timeIntervalSince(start) < 0.1)
    }
}
