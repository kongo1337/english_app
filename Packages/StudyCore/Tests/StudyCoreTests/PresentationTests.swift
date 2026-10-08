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
        #expect(SwipeDecision.direction(forWidth: 100, predictedEndWidth: 100) == .right)
        #expect(SwipeDecision.direction(forWidth: 180, predictedEndWidth: 200) == .right)
        #expect(SwipeDecision.direction(forWidth: -100, predictedEndWidth: -100) == .left)
        #expect(SwipeDecision.direction(forWidth: -250, predictedEndWidth: -250) == .left)
    }

    @Test func shortSlowDragsSpringBack() {
        #expect(SwipeDecision.direction(forWidth: 99, predictedEndWidth: 150) == nil)
        #expect(SwipeDecision.direction(forWidth: -60, predictedEndWidth: -120) == nil)
        #expect(SwipeDecision.direction(forWidth: 0, predictedEndWidth: 0) == nil)
    }

    @Test func quickFlicksCount() {
        #expect(SwipeDecision.direction(forWidth: 40, predictedEndWidth: 400) == .right)
        #expect(SwipeDecision.direction(forWidth: -40, predictedEndWidth: -400) == .left)
    }

    @Test func aFlickMustStartInTheSameDirection() {
        #expect(SwipeDecision.direction(forWidth: 10, predictedEndWidth: 400) == nil)       // barely moved
        #expect(SwipeDecision.direction(forWidth: 40, predictedEndWidth: -400) == nil)      // moved right, flicks left
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

@Suite struct ReviewTextsTests {
    @Test func subtitle() {
        #expect(ReviewTexts.subtitle(remaining: 1) == "Осталось 1 слово")
        #expect(ReviewTexts.subtitle(remaining: 12) == "Осталось 12 слов")
    }

    @Test func tomorrow() {
        #expect(ReviewTexts.emptyMessage(forecast: [0, 35, 4], answeredToday: 0) == "Завтра повторим 35 слов.")
    }

    @Test func laterThisWeek() {
        #expect(ReviewTexts.emptyMessage(forecast: [0, 0, 1], answeredToday: 0) == "Через 2 дня повторим 1 слово.")
        #expect(ReviewTexts.emptyMessage(forecast: [0, 0, 0, 0, 0, 0, 12], answeredToday: 0) == "Через 6 дней повторим 12 слов.")
    }

    @Test func mentionsWhatWasDoneToday() {
        #expect(ReviewTexts.emptyMessage(forecast: [0, 3], answeredToday: 22) == "Сегодня повторено 22 слова. Завтра повторим 3 слова.")
    }

    @Test func reachingTheLimitIsExplained() {
        #expect(ReviewTexts.emptyMessage(forecast: [15, 0], answeredToday: 50)
            == "Сегодня повторено 50 слов. Дневной лимит исчерпан, ещё 15 слов ждут завтра.")
    }

    @Test func nothingScheduledAtAll() {
        #expect(ReviewTexts.emptyMessage(forecast: [0, 0, 0], answeredToday: 0) == "Выучите новые слова: они появятся здесь завтра.")
        #expect(ReviewTexts.emptyMessage(forecast: [], answeredToday: 0) == "Выучите новые слова: они появятся здесь завтра.")
    }
}

@Suite struct ProgressTextsTests {
    @Test func streak() {
        #expect(ProgressTexts.streak(0) == "Серии пока нет")
        #expect(ProgressTexts.streak(1) == "Серия: 1 день")
        #expect(ProgressTexts.streak(3) == "Серия: 3 дня")
        #expect(ProgressTexts.streak(11) == "Серия: 11 дней")
        #expect(ProgressTexts.streak(21) == "Серия: 21 день")
    }

    @Test func dayLabels() {
        #expect(ProgressTexts.dayLabel(0) == "Сегодня")
        #expect(ProgressTexts.dayLabel(1) == "Завтра")
        #expect(ProgressTexts.dayLabel(4) == "+4")
    }
}
