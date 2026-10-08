import StudyCore
import SwiftUI

/// "Новые слова / Выучено 40 из 65 за сегодня" with the direction, help and undo buttons.
struct LearnHeader: View {
    let model: LearnViewModel
    @Binding var showHelp: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Text("Новые слова")
                    .font(Theme.Typography.screenTitle)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 8)
                Button { model.toggleDirection() } label: {
                    ChipLabel { Text(model.direction == .enToRu ? "EN-RU" : "RU-EN") }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(model.direction == .enToRu ? "Направление: с английского на русский" : "Направление: с русского на английский")
                .accessibilityHint("Переключить направление")
                .accessibilityIdentifier("directionButton")

                Button { showHelp = true } label: {
                    HelpChipLabel(showsDot: !model.settings.values.hasSeenHelp)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Справка")
                .accessibilityIdentifier("helpButton")
            }

            HStack {
                Text(model.subtitle)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.textSecondary)
                    .accessibilityIdentifier("headerSubtitle")
                Spacer(minLength: 8)
                Button { model.undo() } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 44, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!model.study.canUndoLearn)
                .opacity(model.study.canUndoLearn ? 1 : 0.3)
                .accessibilityLabel("Отменить")
                .accessibilityIdentifier("undoButton")
            }

            ProgressBar(value: model.progressFraction)
        }
    }
}
