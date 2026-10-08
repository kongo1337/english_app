import Foundation

/// Strings of the Learn screen that depend on numbers; kept apart from the views to be testable.
public enum LearnTexts {
    public static func subtitle(learned: Int, total: Int) -> String {
        "Выучено \(learned) из \(total) за сегодня"
    }

    /// "Выучено 60 из 65. 5 слов перенесём на завтра."
    public static func dayCompleteMessage(learned: Int, total: Int) -> String {
        let carried = max(0, total - learned)
        if carried == 0 {
            return "Выучено \(learned) из \(total). Отличная работа!"
        }
        let verb = RussianPlural.form(carried, one: "слово перенесём", few: "слова перенесём", many: "слов перенесём")
        return "Выучено \(learned) из \(total). \(carried) \(verb) на завтра."
    }

    public static func roundCompleteMessage(remaining: Int) -> String {
        let hard = RussianPlural.form(remaining, one: "трудное слово", few: "трудных слова", many: "трудных слов")
        let left = RussianPlural.form(remaining, one: "Осталось", few: "Осталось", many: "Осталось")
        return "\(left) \(remaining) \(hard). Пройти их ещё раз?"
    }
}

public enum CountdownFormatter {
    /// "11 : 31 : 17". Rounds up, so the display reads 00 : 00 : 01 until the very end.
    public static func format(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        func pad(_ value: Int) -> String { value < 10 ? "0\(value)" : "\(value)" }
        return "\(pad(total / 3600)) : \(pad(total % 3600 / 60)) : \(pad(total % 60))"
    }
}

public enum ReviewTexts {
    /// Under the title of the Review tab: "Осталось 12 слов".
    public static func subtitle(remaining: Int) -> String {
        "Осталось \(RussianPlural.words(remaining))"
    }

    /// What the Review tab says when there is nothing to repeat right now.
    ///
    /// - Parameters:
    ///   - forecast: repetitions due today, tomorrow, … (see `StatsCalculator.reviewForecast`).
    ///   - answeredToday: repetitions already answered today.
    public static func emptyMessage(forecast: [Int], answeredToday: Int) -> String {
        var parts: [String] = []
        if answeredToday > 0 {
            parts.append("Сегодня повторено \(RussianPlural.words(answeredToday)).")
        }
        if let today = forecast.first, today > 0 {
            // Words are due but hidden: the daily limit has been reached.
            parts.append("Дневной лимит исчерпан, ещё \(RussianPlural.words(today)) ждут завтра.")
        } else if let next = forecast.indices.dropFirst().first(where: { forecast[$0] > 0 }) {
            let count = RussianPlural.words(forecast[next])
            if next == 1 {
                parts.append("Завтра повторим \(count).")
            } else {
                let days = RussianPlural.form(next, one: "день", few: "дня", many: "дней")
                parts.append("Через \(next) \(days) повторим \(count).")
            }
        } else {
            parts.append("Выучите новые слова: они появятся здесь завтра.")
        }
        return parts.joined(separator: " ")
    }
}

public enum ProgressTexts {
    /// "Серия: 5 дней" or an invitation when there is no streak.
    public static func streak(_ days: Int) -> String {
        guard days > 0 else { return "Серии пока нет" }
        return "Серия: \(days) \(RussianPlural.form(days, one: "день", few: "дня", many: "дней"))"
    }

    /// Label under the forecast bars: today, tomorrow, then "+2".
    public static func dayLabel(_ offset: Int) -> String {
        switch offset {
        case 0: "Сегодня"
        case 1: "Завтра"
        default: "+\(offset)"
        }
    }
}
