import SwiftUI

/// The capsule buttons of the reference: indigo "primary" and cream "secondary".
struct PillButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary }

    var kind: Kind = .primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.button)
            .foregroundStyle(kind == .primary ? Color.white : Theme.textPrimary)
            .frame(maxWidth: .infinity, minHeight: Theme.Size.pillButtonHeight)
            .background {
                Capsule().fill(kind == .primary ? Theme.accent : Theme.surfaceMuted)
            }
            .overlay {
                if kind == .secondary {
                    Capsule().strokeBorder(Theme.border, lineWidth: 1)
                }
            }
            .shadow(color: kind == .primary ? Theme.accent.opacity(0.28) : .clear, radius: 12, x: 0, y: 8)
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PillButtonStyle {
    static func pill(_ kind: PillButtonStyle.Kind = .primary) -> PillButtonStyle {
        PillButtonStyle(kind: kind)
    }
}
