import StudyCore
import SwiftUI

/// The Review tab: words that are due for repetition.
struct ReviewView: View {
    @State private var model: ReviewViewModel

    init(app: AppEnvironment) {
        _model = State(initialValue: ReviewViewModel(app: app))
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                header
                Spacer(minLength: Theme.Spacing.medium)
                content
                Spacer(minLength: Theme.Spacing.medium)
            }
            .padding(.horizontal, Theme.Spacing.screen)
            .padding(.top, Theme.Spacing.small)
        }
        .onChange(of: model.study.currentReviewWord?.id) { _, _ in model.cardDidChange() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Text("Повторение")
                    .font(Theme.Typography.screenTitle)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityIdentifier("screen.review")
                Spacer(minLength: 8)
                Button { model.toggleDirection() } label: {
                    ChipLabel { Text(model.direction == .enToRu ? "EN-RU" : "RU-EN") }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    model.direction == .enToRu
                        ? "Направление: с английского на русский" : "Направление: с русского на английский")
                .accessibilityHint("Переключить направление")
                .accessibilityIdentifier("directionButton")
            }

            HStack {
                Text(model.subtitle)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.textSecondary)
                    .accessibilityIdentifier("reviewSubtitle")
                Spacer(minLength: 8)
                Button { model.undo() } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 44, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!model.study.canUndoReview)
                .opacity(model.study.canUndoReview ? 1 : 0.3)
                .accessibilityLabel("Отменить")
                .accessibilityIdentifier("undoButton")
            }

            ProgressBar(value: model.progressFraction)
        }
    }

    @ViewBuilder private var content: some View {
        if model.currentWord != nil {
            VStack(spacing: Theme.Spacing.large) {
                FlashCardStack(model: model)

                HStack(spacing: Theme.Spacing.medium) {
                    Button { Task { await model.answer(.forgot) } } label: {
                        Text("Забыл")
                    }
                    .buttonStyle(.pill(.secondary))
                    .accessibilityIdentifier("forgotButton")

                    Button { Task { await model.answer(.remembered) } } label: {
                        Label("Помню", systemImage: "checkmark")
                    }
                    .buttonStyle(.pill(.primary))
                    .accessibilityIdentifier("rememberedButton")
                }
            }
        } else {
            StatusCard(symbol: "checkmark.circle", title: "Повторять нечего", message: model.emptyMessage) {
                EmptyView()
            }
            .accessibilityIdentifier("reviewEmpty")
        }
    }
}
