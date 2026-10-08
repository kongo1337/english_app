import Foundation

/// One local notification to schedule.
public struct PlannedReminder: Equatable, Sendable {
    public let fireDate: Date
    public let body: String

    public init(fireDate: Date, body: String) {
        self.fireDate = fireDate
        self.body = body
    }
}

/// Decides which reminders to schedule for the next days. Pure: the app deletes all pending
/// reminders and schedules these again after every change of progress.
public enum ReminderPlanner {
    public static let horizonDays = 7

    /// - Parameters:
    ///   - now: the current instant.
    ///   - hour/minute: the time of day set in Settings.
    ///   - newRemaining: new words of today's plan not yet learned.
    ///   - reviewForecast: repetitions due today, tomorrow, … (`StatsCalculator.reviewForecast`).
    ///   - reviewsDoneToday: whether today's repetitions have been answered (they are not in the forecast then).
    public static func plan(
        now: Date, hour: Int, minute: Int, clock: DayClock, today: DayKey, newRemaining: Int,
        reviewForecast: [Int]
    ) -> [PlannedReminder] {
        let calendar = clock.calendar
        let startOfToday = calendar.startOfDay(for: now)
        var result: [PlannedReminder] = []
        for offset in 0..<horizonDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfToday),
                  let fire = calendar.date(
                    bySettingHour: min(max(hour, 0), 23), minute: min(max(minute, 0), 59), second: 0, of: day),
                  fire > now
            else { continue }

            // Which study day does this instant belong to, and what will be due then?
            let studyDay = clock.dayKey(for: fire)
            let dayOffset = max(0, today.days(until: studyDay))
            let reviews = dayOffset < reviewForecast.count ? reviewForecast[dayOffset] : 0
            let newWords = dayOffset == 0 ? newRemaining : nil

            if dayOffset == 0, newRemaining == 0, reviews == 0 { continue }
            result.append(PlannedReminder(fireDate: fire, body: ReminderTexts.body(newWords: newWords, reviews: reviews)))
        }
        return result
    }
}

public enum ReminderTexts {
    public static let title = "Пора учить слова"

    /// "Сегодня ещё 25 новых слов и 22 повторения". `newWords` is nil for future days, when the
    /// new set is not known yet.
    public static func body(newWords: Int?, reviews: Int) -> String {
        var parts: [String] = []
        if let newWords, newWords > 0 {
            let word = RussianPlural.form(newWords, one: "новое слово", few: "новых слова", many: "новых слов")
            parts.append("\(newWords) \(word)")
        }
        if reviews > 0 {
            let word = RussianPlural.form(reviews, one: "повторение", few: "повторения", many: "повторений")
            parts.append("\(reviews) \(word)")
        }
        if newWords == nil, parts.isEmpty { return "Новый набор слов уже ждёт." }
        if newWords == nil { return "Ждёт новый набор слов и \(parts.joined(separator: ", "))." }
        return "Сегодня ещё " + parts.joined(separator: " и ") + "."
    }
}
