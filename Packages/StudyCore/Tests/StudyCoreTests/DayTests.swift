import Foundation
import Testing
@testable import StudyCore

@Suite struct DayKeyTests {
    @Test func parsesAndPrints() {
        let key = DayKey("2026-10-08")
        #expect(key == DayKey(year: 2026, month: 10, day: 8))
        #expect(key?.description == "2026-10-08")
        #expect(DayKey("2026-02-30") == nil)
        #expect(DayKey("2026-13-01") == nil)
        #expect(DayKey("garbage") == nil)
    }

    @Test func epochIsDayZero() {
        #expect(DayKey(year: 1970, month: 1, day: 1).daysSinceEpoch == 0)
        #expect(DayKey(daysSinceEpoch: 0) == DayKey(year: 1970, month: 1, day: 1))
    }

    @Test func arithmeticCrossesMonthsYearsAndLeapDays() {
        let end = DayKey(year: 2026, month: 12, day: 31)
        #expect(end.adding(days: 1) == DayKey(year: 2027, month: 1, day: 1))
        #expect(DayKey(year: 2028, month: 2, day: 28).adding(days: 1) == DayKey(year: 2028, month: 2, day: 29))
        #expect(DayKey(year: 2027, month: 2, day: 28).adding(days: 1) == DayKey(year: 2027, month: 3, day: 1))
        #expect(DayKey(year: 2026, month: 3, day: 1).adding(days: -1) == DayKey(year: 2026, month: 2, day: 28))
        #expect(DayKey(year: 2026, month: 1, day: 1).days(until: DayKey(year: 2027, month: 1, day: 1)) == 365)
    }

    @Test func roundTripsForManyDays() {
        for offset in stride(from: -300_000, through: 600_000, by: 997) {
            let key = DayKey(daysSinceEpoch: offset)
            #expect(key.daysSinceEpoch == offset)
            #expect(DayKey(key.description) == key)
        }
    }

    @Test func ordersChronologically() {
        #expect(DayKey(year: 2026, month: 1, day: 31) < DayKey(year: 2026, month: 2, day: 1))
        #expect(DayKey(year: 2025, month: 12, day: 31) < DayKey(year: 2026, month: 1, day: 1))
    }

    @Test func encodesAsString() throws {
        let data = try JSONEncoder().encode([DayKey(year: 2026, month: 5, day: 3)])
        #expect(String(decoding: data, as: UTF8.self) == "[\"2026-05-03\"]")
        let decoded = try JSONDecoder().decode([DayKey].self, from: data)
        #expect(decoded == [DayKey(year: 2026, month: 5, day: 3)])
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode([DayKey].self, from: Data("[\"nope\"]".utf8))
        }
    }
}

@Suite struct DayClockTests {
    @Test func dayStartsAtConfiguredHour() {
        let clock = clock(dayStartHour: 4)
        #expect(clock.dayKey(for: date(2026, 10, 8, 3, 59)) == DayKey(year: 2026, month: 10, day: 7))
        #expect(clock.dayKey(for: date(2026, 10, 8, 4, 0)) == DayKey(year: 2026, month: 10, day: 8))
        #expect(clock.dayKey(for: date(2026, 10, 8, 23, 59)) == DayKey(year: 2026, month: 10, day: 8))
        #expect(clock.dayKey(for: date(2026, 10, 9, 0, 30)) == DayKey(year: 2026, month: 10, day: 8))
    }

    @Test func midnightStartWorks() {
        let clock = clock(dayStartHour: 0)
        #expect(clock.dayKey(for: date(2026, 10, 8, 0, 0)) == DayKey(year: 2026, month: 10, day: 8))
        #expect(clock.dayKey(for: date(2026, 10, 7, 23, 59)) == DayKey(year: 2026, month: 10, day: 7))
    }

    @Test func january1stBeforeStartHourBelongsToPreviousYear() {
        let clock = clock(dayStartHour: 4)
        #expect(clock.dayKey(for: date(2027, 1, 1, 2, 0)) == DayKey(year: 2026, month: 12, day: 31))
    }

    @Test func countdownTargetsNextDayStart() {
        let clock = clock(dayStartHour: 4)
        let evening = date(2026, 10, 8, 16, 30)
        #expect(clock.startOfNextDay(after: evening) == date(2026, 10, 9, 4, 0))
        #expect(clock.secondsUntilNextDay(from: evening) == 11.5 * 3600)
        let night = date(2026, 10, 9, 3, 0)
        #expect(clock.startOfNextDay(after: night) == date(2026, 10, 9, 4, 0))
        #expect(clock.secondsUntilNextDay(from: night) == 3600)
    }

    @Test func timeZoneChangeRecomputesTheKey() {
        let instant = date(2026, 10, 8, 22, 30, zone: "Europe/Moscow")  // 19:30 UTC
        #expect(clock(zone: "Europe/Moscow").dayKey(for: instant) == DayKey(year: 2026, month: 10, day: 8))
        // In Tokyo the same instant is 04:30 on the 9th.
        #expect(clock(zone: "Asia/Tokyo").dayKey(for: instant) == DayKey(year: 2026, month: 10, day: 9))
    }

    @Test func daylightSavingDoesNotShiftTheBoundary() {
        // US clocks go back on 2026-11-01: that local day lasts 25 hours.
        let clock = clock(zone: "America/New_York", dayStartHour: 4)
        #expect(clock.dayKey(for: date(2026, 11, 1, 3, 30, zone: "America/New_York")) == DayKey(year: 2026, month: 10, day: 31))
        #expect(clock.dayKey(for: date(2026, 11, 1, 4, 0, zone: "America/New_York")) == DayKey(year: 2026, month: 11, day: 1))
        let start = clock.startOfNextDay(after: date(2026, 11, 1, 12, 0, zone: "America/New_York"))
        #expect(start == date(2026, 11, 2, 4, 0, zone: "America/New_York"))
        // From noon on the long day: 16 h + 1 extra hour.
        #expect(clock.secondsUntilNextDay(from: date(2026, 11, 1, 12, 0, zone: "America/New_York")) == 16 * 3600)
    }
}

@Suite struct SeededRandomTests {
    @Test func sameSeedSameSequence() {
        var a = SeededRandom(seed: 42), b = SeededRandom(seed: 42)
        #expect((0..<20).map { _ in a.next() } == (0..<20).map { _ in b.next() })
    }

    @Test func differentSeedsDiffer() {
        var a = SeededRandom(seed: 1), b = SeededRandom(seed: 2)
        #expect(a.next() != b.next())
    }

    @Test func stableValueIsStableAndKeyDependent() {
        #expect(SeededRandom.stableValue(seed: 7, key: "abandon_verb") == SeededRandom.stableValue(seed: 7, key: "abandon_verb"))
        #expect(SeededRandom.stableValue(seed: 7, key: "abandon_verb") != SeededRandom.stableValue(seed: 7, key: "abandon_noun"))
        #expect(SeededRandom.stableValue(seed: 7, key: "x") != SeededRandom.stableValue(seed: 8, key: "x"))
    }
}
