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
