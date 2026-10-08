import StudyCore
import SwiftUI

/// "ДО НОВЫХ СЛОВ 11 : 31 : 17": counts down to the start of the next study day.
struct CountdownPanel: View {
    let title: LocalizedStringKey
    /// Called every second; returns the seconds left.
    let secondsRemaining: () -> TimeInterval

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(Theme.Typography.small)
                .foregroundStyle(Theme.textSecondary)
                .textCase(.uppercase)
                .tracking(1.2)
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                Text(CountdownFormatter.format(secondsRemaining()))
                    .font(Theme.Typography.timer)
                    .foregroundStyle(Theme.textPrimary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .accessibilityIdentifier("countdown")
            }
        }
        .padding(.vertical, Theme.Spacing.medium)
        .frame(maxWidth: .infinity)
        .background(Theme.surfaceMuted, in: RoundedRectangle(cornerRadius: 36, style: .continuous))
    }
}
