import StudyCore
import SwiftUI

/// The main screen: today's cards, or the state that replaces them.
struct LearnView: View {
    @State private var model: LearnViewModel
    @State private var showHelp = false
    let openReview: () -> Void

    init(app: AppEnvironment, openReview: @escaping () -> Void) {
        _model = State(initialValue: LearnViewModel(app: app))
        self.openReview = openReview
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                LearnHeader(model: model, showHelp: $showHelp)
                Spacer(minLength: Theme.Spacing.medium)
                content
                Spacer(minLength: Theme.Spacing.medium)
            }
            .scrollsAtAccessibilitySizes()
            .padding(.horizontal, Theme.Spacing.screen)
            .padding(.top, Theme.Spacing.small)
        }
        .sheet(isPresented: $showHelp, onDismiss: { model.markHelpSeen() }) {
            HelpSheet()
        }
        .task {
            if !model.settings.values.hasSeenHelp { showHelp = true }
        }
        .onChange(of: model.study.currentWord?.id) { _, _ in model.cardDidChange() }
    }

    @ViewBuilder private var content: some View {
        switch model.study.phase {
        case .card:
            CardStack(model: model)
        case .roundComplete(let remaining):
            StatusCard(
                symbol: "arrow.triangle.2.circlepath", title: "Круг пройден",
                message: LearnTexts.roundCompleteMessage(remaining: remaining)
            ) {
                VStack(spacing: Theme.Spacing.small) {
                    Button("Пройти ещё раз") { model.continueRound() }
                        .buttonStyle(.pill(.primary))
                        .accessibilityIdentifier("continueRoundButton")
                    Button("На сегодня хватит") { model.finishForToday() }
                        .buttonStyle(.pill(.secondary))
                        .accessibilityIdentifier("finishDayButton")
                }
            }
            .accessibilityIdentifier("roundComplete")
        case .dayComplete:
            DayCompleteCard(model: model, openReview: openReview)
        case .allDone:
            StatusCard(
                symbol: "trophy", title: "Все слова пройдены",
                message: "Вы просмотрели все слова из включённых словарей. Теперь главное — повторения."
            ) {
                if model.study.reviewDueCount > 0 {
                    Button("Повторить · \(model.study.reviewDueCount)") { openReview() }
                        .buttonStyle(.pill(.primary))
                }
            }
            .accessibilityIdentifier("allDone")
        }
    }
}

/// The cards and the two buttons under them.
private struct CardStack: View {
    let model: LearnViewModel

    var body: some View {
        VStack(spacing: Theme.Spacing.large) {
            FlashCardStack(model: model)

            ButtonRow {
                Button { Task { await model.decide(.stillLearning) } } label: {
                    Text("Ещё учу")
                }
                .buttonStyle(.pill(.secondary))
                .accessibilityIdentifier("stillLearningButton")
            } trailing: {
                Button { Task { await model.decide(.learned) } } label: {
                    Label("Выучил", systemImage: "checkmark")
                }
                .buttonStyle(.pill(.primary))
                .accessibilityIdentifier("learnedButton")
            }
        }
    }
}

/// "На сегодня всё": the plan is done; wait for tomorrow, repeat, or take more words.
private struct DayCompleteCard: View {
    let model: LearnViewModel
    let openReview: () -> Void

    var body: some View {
        let study = model.study
        let extra = study.studySettings.extraBatchSize
        StatusCard(
            symbol: "checkmark", title: "На сегодня всё!",
            message: LearnTexts.dayCompleteMessage(learned: study.plan.learnedCount, total: study.plan.totalCount)
        ) {
            VStack(spacing: Theme.Spacing.medium) {
                CountdownPanel(title: "До новых слов") { study.secondsUntilNextDay }
                if study.reviewDueCount > 0 {
                    Button("Повторить · \(study.reviewDueCount)") { openReview() }
                        .buttonStyle(.pill(.primary))
                        .accessibilityIdentifier("openReviewButton")
                }
                if study.hasNewWords {
                    Button("Ещё \(RussianPlural.words(extra))") { model.addMoreWords() }
                        .buttonStyle(.pill(study.reviewDueCount > 0 ? .secondary : .primary))
                        .accessibilityIdentifier("moreWordsButton")
                }
            }
        }
        .accessibilityIdentifier("dayComplete")
    }
}
