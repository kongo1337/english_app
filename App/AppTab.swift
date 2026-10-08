import SwiftUI

/// The five tabs of the app, in the order of the bottom bar.
enum AppTab: String, CaseIterable, Identifiable {
    case learn, review, dictionaries, progress, settings

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .learn: "Учить"
        case .review: "Повторить"
        case .dictionaries: "Словари"
        case .progress: "Прогресс"
        case .settings: "Настройки"
        }
    }

    var symbol: String {
        switch self {
        case .learn: "book"
        case .review: "arrow.triangle.2.circlepath"
        case .dictionaries: "square.grid.2x2"
        case .progress: "chart.bar"
        case .settings: "gearshape"
        }
    }
}
