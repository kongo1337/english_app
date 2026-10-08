import StudyCore
import SwiftUI

/// The round / pill header buttons ("RU-EN", "?", undo).
struct ChipLabel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .font(Theme.Typography.bodyEmphasized)
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 14)
            .frame(minWidth: Theme.Size.chip, minHeight: Theme.Size.chip)
            .background(Theme.surfaceMuted, in: Capsule())
            .overlay { Capsule().strokeBorder(Theme.border, lineWidth: 1) }
            .contentShape(Capsule())
    }
}

/// "?" with the red dot that disappears once the help has been opened.
struct HelpChipLabel: View {
    var showsDot: Bool

    var body: some View {
        ChipLabel { Text("?") }
            .overlay(alignment: .topTrailing) {
                if showsDot {
                    Circle()
                        .fill(Theme.badge)
                        .frame(width: 12, height: 12)
                        .offset(x: 1, y: -1)
                        .accessibilityHidden(true)
                }
            }
    }
}

/// "B1" in the colour of its level.
struct LevelChip: View {
    let level: CEFRLevel

    var body: some View {
        Text(level.rawValue)
            .font(.system(.caption, design: .rounded, weight: .bold))
            .foregroundStyle(Theme.level(level))
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(Theme.level(level).opacity(0.14), in: Capsule())
            .accessibilityLabel("Уровень \(level.rawValue)")
    }
}
