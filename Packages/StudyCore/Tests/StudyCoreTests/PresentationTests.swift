import Foundation
import Testing
@testable import StudyCore

@Suite struct RussianPluralTests {
    @Test func picksTheRightForm() {
        let cases: [(Int, String)] = [
            (0, "слов"), (1, "слово"), (2, "слова"), (4, "слова"), (5, "слов"), (10, "слов"),
            (11, "слов"), (12, "слов"), (14, "слов"), (21, "слово"), (22, "слова"), (25, "слов"),
            (101, "слово"), (111, "слов"), (112, "слов"), (1002, "слова"),
        ]
        for (count, expected) in cases {
            #expect(RussianPlural.form(count, one: "слово", few: "слова", many: "слов") == expected, "\(count)")
        }
    }

    @Test func formatsCounts() {
        #expect(RussianPlural.words(1) == "1 слово")
        #expect(RussianPlural.words(5) == "5 слов")
        #expect(RussianPlural.repetitions(22) == "22 повторения")
        #expect(RussianPlural.repetitions(11) == "11 повторений")
    }
}

@Suite struct LearnTextsTests {
    @Test func subtitleMatchesTheReference() {
        #expect(LearnTexts.subtitle(learned: 40, total: 65) == "Выучено 40 из 65 за сегодня")
    }

    @Test func dayCompleteMessage() {
        #expect(LearnTexts.dayCompleteMessage(learned: 60, total: 65) == "Выучено 60 из 65. 5 слов перенесём на завтра.")
        #expect(LearnTexts.dayCompleteMessage(learned: 64, total: 65) == "Выучено 64 из 65. 1 слово перенесём на завтра.")
        #expect(LearnTexts.dayCompleteMessage(learned: 63, total: 65) == "Выучено 63 из 65. 2 слова перенесём на завтра.")
        #expect(LearnTexts.dayCompleteMessage(learned: 65, total: 65) == "Выучено 65 из 65. Отличная работа!")
    }

    @Test func roundCompleteMessage() {
        #expect(LearnTexts.roundCompleteMessage(remaining: 1) == "Осталось 1 трудное слово. Пройти их ещё раз?")
        #expect(LearnTexts.roundCompleteMessage(remaining: 3) == "Осталось 3 трудных слова. Пройти их ещё раз?")
        #expect(LearnTexts.roundCompleteMessage(remaining: 12) == "Осталось 12 трудных слов. Пройти их ещё раз?")
    }

    @Test func countdownFormat() {
        #expect(CountdownFormatter.format(11 * 3600 + 31 * 60 + 17) == "11 : 31 : 17")
        #expect(CountdownFormatter.format(0) == "00 : 00 : 00")
        #expect(CountdownFormatter.format(-5) == "00 : 00 : 00")
        #expect(CountdownFormatter.format(59.2) == "00 : 01 : 00")  // rounded up: still one second to go
        #expect(CountdownFormatter.format(0.4) == "00 : 00 : 01")
        #expect(CountdownFormatter.format(24 * 3600) == "24 : 00 : 00")
    }
}

@Suite struct SwipeDecisionTests {
    @Test func farDragsAreDecisions() {
        #expect(SwipeDecision.action(forWidth: 100, predictedEndWidth: 100) == .learned)
        #expect(SwipeDecision.action(forWidth: 180, predictedEndWidth: 200) == .learned)
        #expect(SwipeDecision.action(forWidth: -100, predictedEndWidth: -100) == .stillLearning)
        #expect(SwipeDecision.action(forWidth: -250, predictedEndWidth: -250) == .stillLearning)
    }

    @Test func shortSlowDragsSpringBack() {
        #expect(SwipeDecision.action(forWidth: 99, predictedEndWidth: 150) == nil)
        #expect(SwipeDecision.action(forWidth: -60, predictedEndWidth: -120) == nil)
        #expect(SwipeDecision.action(forWidth: 0, predictedEndWidth: 0) == nil)
    }

    @Test func quickFlicksCount() {
        #expect(SwipeDecision.action(forWidth: 40, predictedEndWidth: 400) == .learned)
        #expect(SwipeDecision.action(forWidth: -40, predictedEndWidth: -400) == .stillLearning)
    }

    @Test func aFlickMustStartInTheSameDirection() {
        #expect(SwipeDecision.action(forWidth: 10, predictedEndWidth: 400) == nil)       // barely moved
        #expect(SwipeDecision.action(forWidth: 40, predictedEndWidth: -400) == nil)      // moved right, flicks left
    }

    @Test func hintGrowsUpToTheThreshold() {
        #expect(SwipeDecision.hintProgress(forWidth: 0) == 0)
        #expect(SwipeDecision.hintProgress(forWidth: 50) == 0.5)
        #expect(SwipeDecision.hintProgress(forWidth: -50) == 0.5)
        #expect(SwipeDecision.hintProgress(forWidth: 400) == 1)
    }

    @Test func rotationIsClamped() {
        #expect(SwipeDecision.rotation(forWidth: 0) == 0)
        #expect(SwipeDecision.rotation(forWidth: 100) == 5)
        #expect(SwipeDecision.rotation(forWidth: 1000) == 12)
        #expect(SwipeDecision.rotation(forWidth: -1000) == -12)
    }
}

@Suite struct WordDisplayTests {
    @Test func partOfSpeechLabels() {
        #expect(PartOfSpeech.noun.shortRussianName == "сущ.")
        #expect(PartOfSpeech.verb.shortRussianName == "гл.")
        #expect(Set(PartOfSpeech.allCases.map(\.shortRussianName)).count == PartOfSpeech.allCases.count)  // all labels differ
    }

    @Test func headerDetailJoinsPartOfSpeechAndSense() {
        let plain = Word(id: "a", lemma: "dog", pos: .noun, cefr: .a1, list: .ox3000, translations: ["собака"], order: 1)
        let sensed = Word(id: "b", lemma: "bank", sense: "money", pos: .noun, cefr: .a1, list: .ox3000, translations: ["банк"], order: 2)
        let other = Word(id: "c", lemma: "x", pos: .other, cefr: .a1, list: .ox3000, translations: ["х"], order: 3)
        #expect(plain.headerDetail == "сущ.")
        #expect(sensed.headerDetail == "сущ. · money")
        #expect(other.headerDetail == "")
    }

    private func highlighted(_ text: String, _ lemma: String) -> String? {
        ExampleHighlighter.range(of: lemma, in: text).map { String(text[$0]) }
    }

    @Test func findsTheWordAndItsForms() {
        #expect(highlighted("They had to abandon the car.", "abandon") == "abandon")
        #expect(highlighted("They abandoned the car.", "abandon") == "abandoned")
        #expect(highlighted("Close the door, please.", "close") == "Close")
        #expect(highlighted("She is a very attractive woman.", "attractive") == "attractive")
        #expect(highlighted("We are running late.", "run") == nil)         // short words must match whole
        #expect(highlighted("I run every day.", "run") == "run")
        #expect(highlighted("Look at the pictures.", "picture") == "pictures")
    }

    @Test func doesNotMatchInsideOtherWords() {
        #expect(highlighted("It was a good spot.", "pot") == nil)
        #expect(highlighted("The pocket is small.", "pot") == nil)
        #expect(highlighted("I went home.", "go") == nil)
    }

    @Test func handlesMultiWordLemmas() {
        #expect(highlighted("I have to go now.", "have to") == "have")
        #expect(highlighted("Tell me about it.", "a, an") == nil)   // "a" is too short to look for
    }

    @Test func worksOnTheRealDictionaryExamples() throws {
        // Most examples contain the studied word or a regular form of it.
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        let catalog = try WordCatalog.load(contentsOf: url.appendingPathComponent("App/Resources/words.json"))
        let found = catalog.words.filter { word in
            word.exampleEN.map { ExampleHighlighter.range(of: word.lemma, in: $0) != nil } ?? false
        }.count
        #expect(Double(found) / Double(catalog.count) > 0.85, "only \(found) of \(catalog.count) examples highlight")
    }
}
