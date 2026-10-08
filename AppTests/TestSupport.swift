import Foundation
import StudyCore

@testable import EnglishCards

/// A small synthetic dictionary: `count` words of the Oxford 3000.
func makeTestCatalog(count: Int = 120) throws -> WordCatalog {
    let levels: [CEFRLevel] = [.a1, .a2, .b1, .b2]
    let words = (1...count).map { index in
        Word(
            id: "w\(index)", lemma: "word\(index)", pos: .noun, cefr: levels[(index - 1) * 4 / count],
            list: .ox3000, translations: ["слово \(index)"], order: index)
    }
    return try WordCatalog(words: words, version: 1)
}

func testDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Moscow")!
    return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
}

func testClock() -> DayClock {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Moscow")!
    return DayClock(calendar: calendar, dayStartHour: 4)
}

/// A controllable "now".
@MainActor
final class TestNow {
    var value: Date
    init(_ value: Date) { self.value = value }
}

/// A throw-away `UserDefaults` domain.
func makeTestDefaults() -> UserDefaults {
    let name = "tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}

/// Records what was spoken.
@MainActor
final class SpySpeech: Speaking {
    private(set) var spoken: [(text: String, accent: SpeechAccent, speed: SpeechSpeed)] = []
    private(set) var stopCount = 0

    func speak(_ text: String, accent: SpeechAccent, speed: SpeechSpeed) {
        spoken.append((text, accent, speed))
    }

    func stop() { stopCount += 1 }
}
