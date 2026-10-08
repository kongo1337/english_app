import Foundation
import Testing
@testable import StudyCore

/// A catalog of synthetic words: `ox3000` words spread over A1…B2, `ox5000` over B2…C1.
func makeCatalog(ox3000: Int = 100, ox5000: Int = 50) throws -> WordCatalog {
    var words: [Word] = []
    let levels3000: [CEFRLevel] = [.a1, .a2, .b1, .b2]
    let levels5000: [CEFRLevel] = [.b2, .c1]
    for index in 1...max(ox3000, 1) where index <= ox3000 {
        words.append(testWord(index, list: .ox3000, level: levels3000[(index - 1) * 4 / ox3000]))
    }
    for index in 1...max(ox5000, 1) where index <= ox5000 {
        words.append(testWord(1000 + index, list: .ox5000, level: levels5000[(index - 1) * 2 / ox5000]))
    }
    return try WordCatalog(words: words, version: 1)
}

func testWord(_ number: Int, list: WordList, level: CEFRLevel) -> Word {
    let name = "word\(number)"
    return Word(
        id: "w\(number)", lemma: name, pos: .noun, cefr: level, list: list,
        translations: ["слово \(number)"], order: number)
}

/// A fixed point in time in the given time zone.
func date(
    _ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0,
    zone: String = "Europe/Moscow"
) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: zone)!
    return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

func clock(zone: String = "Europe/Moscow", dayStartHour: Int = 4) -> DayClock {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: zone)!
    return DayClock(calendar: calendar, dayStartHour: dayStartHour)
}

/// A controllable "now" for engine tests.
@MainActor
final class TestNow {
    var value: Date
    init(_ value: Date) { self.value = value }

    func advance(days: Int, hour: Int = 12) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Moscow")!
        let next = calendar.date(byAdding: .day, value: days, to: value)!
        value = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: next)!
    }
}

@MainActor
func makeEngine(
    catalog: WordCatalog, repository: InMemoryProgressRepository = InMemoryProgressRepository(),
    settings: StudySettings = StudySettings(), now: TestNow
) throws -> StudyEngine {
    try StudyEngine(
        catalog: catalog, repository: repository, settings: settings, clock: clock(),
        now: { now.value })
}

func progressMap(_ items: [WordProgress]) -> [String: WordProgress] {
    Dictionary(uniqueKeysWithValues: items.map { ($0.wordId, $0) })
}
