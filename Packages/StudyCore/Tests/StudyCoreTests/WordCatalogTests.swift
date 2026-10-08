import Foundation
import Testing
@testable import StudyCore

private func repositoryRoot(from file: String = #filePath) -> URL {
    var url = URL(fileURLWithPath: file)
    for _ in 0..<5 { url.deleteLastPathComponent() }  // file, StudyCoreTests, Tests, StudyCore, Packages
    return url
}

@Suite struct WordCatalogTests {
    @Test func rejectsDuplicateIds() {
        let word = testWord(1, list: .ox3000, level: .a1)
        #expect(throws: WordCatalogError.duplicateId("w1")) {
            try WordCatalog(words: [word, word])
        }
    }

    @Test func looksUpAndFilters() throws {
        let catalog = try makeCatalog(ox3000: 40, ox5000: 20)
        #expect(catalog.count == 60)
        #expect(catalog.word(id: "w5")?.lemma == "word5")
        #expect(catalog.word(id: "nope") == nil)
        #expect(catalog.count(in: .ox3000) == 40)
        #expect(catalog.words(in: .ox5000).count == 20)
        #expect(Set(catalog.words(at: .c1).map(\.list)) == [.ox5000])
    }

    @Test func searchRanksExactThenPrefixThenContains() throws {
        let words = [
            Word(id: "a", lemma: "stand", pos: .verb, cefr: .a1, list: .ox3000, translations: ["стоять"], order: 1),
            Word(id: "b", lemma: "understand", pos: .verb, cefr: .a1, list: .ox3000, translations: ["понимать"], order: 2),
            Word(id: "c", lemma: "standard", pos: .noun, cefr: .b1, list: .ox3000, translations: ["стандарт"], order: 3),
            Word(id: "d", lemma: "chair", pos: .noun, cefr: .a1, list: .ox3000, translations: ["стул", "кресло"], order: 4),
            Word(id: "e", lemma: "sofa", pos: .noun, cefr: .a1, list: .ox3000, translations: ["диван (стул)"], order: 5),
            Word(id: "f", lemma: "year", pos: .noun, cefr: .a1, list: .ox3000, translations: ["ёлка"], order: 6),
        ]
        let catalog = try WordCatalog(words: words)
        #expect(catalog.search("stand").map(\.id) == ["a", "c", "b"])
        #expect(catalog.search("  STAND ").map(\.id) == ["a", "c", "b"])
        #expect(catalog.search("стул").map(\.id) == ["d", "e"])  // prefix match before substring match
        #expect(catalog.search("елка").map(\.id) == ["f"])  // е matches ё
        #expect(catalog.search("").isEmpty)
        #expect(catalog.search("zzz").isEmpty)
        #expect(catalog.search("stand", limit: 1).count == 1)
    }

    @Test func decodesTheFileFormat() throws {
        let json = """
        {"version":3,"counts":{},"words":[{"id":"close-2_adjective","lemma":"close","sense":null,"pos":"adjective",
        "cefr":"A2","list":"ox3000","ipa":"/ˈkloʊs/","translations":["близкий"],"exampleEN":"Close to home.",
        "exampleRU":"Недалеко от дома.","order":1243}]}
        """
        let catalog = try WordCatalog.load(data: Data(json.utf8))
        #expect(catalog.version == 3)
        let word = try #require(catalog.word(id: "close-2_adjective"))
        #expect(word.pos == .adjective && word.cefr == .a2 && word.list == .ox3000)
        #expect(word.sense == nil && word.primaryTranslation == "близкий")
    }
}

@Suite struct RealDictionaryTests {
    private func load() throws -> (WordCatalog, TimeInterval) {
        let url = repositoryRoot().appendingPathComponent("App/Resources/words.json")
        let data = try Data(contentsOf: url)
        let start = Date.timeIntervalSinceReferenceDate
        let catalog = try WordCatalog.load(data: data)
        return (catalog, Date.timeIntervalSinceReferenceDate - start)
    }

    @Test func hasTheExpectedSize() throws {
        let (catalog, _) = try load()
        #expect(catalog.count == 5938)
        #expect(catalog.count(in: .ox3000) == 3809)
        #expect(catalog.count(in: .ox5000) == 2129)
    }

    @Test func everyWordIsComplete() throws {
        let (catalog, _) = try load()
        for word in catalog.words {
            #expect(!word.translations.isEmpty, "\(word.id) has no translation")
            #expect(word.exampleEN?.isEmpty == false && word.exampleRU?.isEmpty == false, "\(word.id) has no example")
            #expect(word.list == .ox3000 ? word.cefr <= .b2 : word.cefr >= .b2, "\(word.id): level \(word.cefr) in \(word.list)")
        }
    }

    @Test func loadsQuickly() throws {
        let (_, seconds) = try load()
        // The spec asks for 300 ms; debug builds are several times slower than release, so
        // this only guards against an accidental order-of-magnitude regression.
        #expect(seconds < 1.5, "loading took \(seconds) s")
    }

    @Test func findsWordsByEnglishAndRussian() throws {
        let (catalog, _) = try load()
        #expect(catalog.search("aban").contains { $0.lemma == "abandon" })
        #expect(catalog.search("бросать").contains { $0.lemma == "abandon" })
        #expect(catalog.search("close").prefix(3).allSatisfy { $0.lemma == "close" })
    }

    @Test func searchIsFastEnoughForTyping() throws {
        let (catalog, _) = try load()
        let start = Date.timeIntervalSinceReferenceDate
        for query in ["a", "ab", "aba", "ст", "сто", "стол"] { _ = catalog.search(query) }
        #expect((Date.timeIntervalSinceReferenceDate - start) / 6 < 0.1)
    }
}
