import SwiftUI

/// The white rounded card with a hairline border and a soft shadow.
struct CardSurface: View {
    var body: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
            .fill(Theme.surface)
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 1)
            }
            .cardShadow()
    }
}

/// A card that shows a state instead of a word: an indigo icon, a title, a message and
/// whatever controls belong to the state ("Карточки на паузе" in the reference).
struct StatusCard<Controls: View>: View {
    let symbol: String
    let title: LocalizedStringKey
    let message: String
    @ViewBuilder var controls: Controls

    var body: some View {
        VStack(spacing: Theme.Spacing.medium) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(
                    LinearGradient(
                        colors: [Theme.accentGradientTop, Theme.accent], startPoint: .top, endPoint: .bottom),
                    in: Circle()
                )
                .shadow(color: Theme.accent.opacity(0.3), radius: 10, x: 0, y: 6)
                .accessibilityHidden(true)

            Text(title)
                .font(Theme.Typography.cardTitle)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)

            Text(message)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            controls
        }
        .padding(Theme.Spacing.large)
        .frame(maxWidth: .infinity)
        .background { CardSurface() }
        .accessibilityElement(children: .contain)
    }
}
