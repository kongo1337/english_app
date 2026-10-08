import StudyCore
import SwiftUI

extension WordStatus {
    var title: String {
        switch self {
        case .new: "Новое"
        case .learning: "Учу"
        case .review: "На повторении"
        case .mastered: "Освоено"
        case .known: "Знаю"
        }
    }

    var color: Color {
        switch self {
        case .new: Theme.textSecondary
        case .learning: Theme.warning
        case .review: Theme.accent
        case .mastered, .known: Theme.success
        }
    }

    var symbol: String {
        switch self {
        case .new: "circle"
        case .learning: "circle.lefthalf.filled"
        case .review: "arrow.triangle.2.circlepath"
        case .mastered: "checkmark.circle.fill"
        case .known: "checkmark.seal.fill"
        }
    }
}

extension StatusFilter {
    var title: String {
        switch self {
        case .new: "Новые"
        case .learning: "Учу"
        case .review: "Повторение"
        case .mastered: "Освоены"
        case .known: "Знаю"
        case .hard: "Трудные"
        case .favorite: "Избранное"
        }
    }
}

extension WordSort {
    var title: String {
        switch self {
        case .dictionary: "Как в словаре"
        case .alphabetical: "По алфавиту"
        case .recent: "Недавно виденные"
        }
    }
}

extension WordList {
    var title: String { self == .ox3000 ? "Oxford 3000" : "Oxford 5000" }
    var subtitle: String { self == .ox3000 ? "Основные слова, A1–B2" : "Продвинутые слова, B2–C1" }
}
