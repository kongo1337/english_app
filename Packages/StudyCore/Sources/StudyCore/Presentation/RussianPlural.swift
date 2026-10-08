import Foundation

public enum RussianPlural {
    /// Picks the Russian noun form for a count: 1 слово, 2 слова, 5 слов, 11 слов, 21 слово.
    public static func form(_ count: Int, one: String, few: String, many: String) -> String {
        let lastTwo = abs(count) % 100
        let last = lastTwo % 10
        if (11...14).contains(lastTwo) { return many }
        switch last {
        case 1: return one
        case 2...4: return few
        default: return many
        }
    }

    public static func words(_ count: Int) -> String {
        "\(count) " + form(count, one: "слово", few: "слова", many: "слов")
    }

    public static func repetitions(_ count: Int) -> String {
        "\(count) " + form(count, one: "повторение", few: "повторения", many: "повторений")
    }
}
