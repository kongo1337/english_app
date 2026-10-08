import Foundation

/// Maps instants to "study days". A study day starts at `dayStartHour` local time (04:00 by
/// default), so a session at 01:00 still belongs to the previous day.
///
/// The clock never reads the system time itself: callers pass the instant in, which keeps
/// all day logic testable. The app provides `Date()` at its edge.
public struct DayClock: Sendable {
    public var calendar: Calendar
    public var dayStartHour: Int

    public init(calendar: Calendar = .current, dayStartHour: Int = 4) {
        self.calendar = calendar
        self.dayStartHour = min(max(dayStartHour, 0), 23)
    }

    public func dayKey(for date: Date) -> DayKey {
        let parts = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        let key = DayKey(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
        return (parts.hour ?? 0) < dayStartHour ? key.adding(days: -1) : key
    }

    /// The instant at which `key` begins.
    public func startOfDay(_ key: DayKey) -> Date {
        let parts = DateComponents(year: key.year, month: key.month, day: key.day, hour: dayStartHour)
        return calendar.date(from: parts) ?? Date(timeIntervalSince1970: Double(key.daysSinceEpoch) * 86_400)
    }

    /// The instant at which the study day after the one containing `date` begins.
    public func startOfNextDay(after date: Date) -> Date {
        startOfDay(dayKey(for: date).adding(days: 1))
    }

    /// Seconds until the next study day starts (never negative).
    public func secondsUntilNextDay(from date: Date) -> TimeInterval {
        max(0, startOfNextDay(after: date).timeIntervalSince(date))
    }
}
