import StudyCore
import SwiftUI

/// One word with everything the card shows, its learning history and the manual actions.
struct WordDetailView: View {
    let app: AppEnvironment
    let wordId: String

    @State private var confirmReset = false

    private var study: StudyService { app.study }
    private var word: Word? { study.catalog.word(id: wordId) }
    private var progress: WordProgress? { study.progress[wordId] }
    private var status: WordStatus { study.status(of: wordId) }

    var body: some View {
        ScrollView {
            if let word {
                VStack(alignment: .leading, spacing: Theme.Spacing.large) {
                    header(word)
                    translations(word)
                    if word.exampleEN != nil { example(word) }
                    history
                    actions(word)
                }
                .padding(.horizontal, Theme.Spacing.screen)
                .padding(.vertical, Theme.Spacing.large)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { study.toggleFavorite(wordId) } label: {
                    Image(systemName: progress?.isFavorite == true ? "star.fill" : "star")
                        .foregroundStyle(progress?.isFavorite == true ? Theme.warning : Theme.textPrimary)
                }
                .accessibilityLabel(progress?.isFavorite == true ? "Убрать из избранного" : "В избранное")
                .accessibilityIdentifier("favoriteButton")
            }
        }
        .confirmationDialog("Сбросить прогресс этого слова?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Сбросить", role: .destructive) { study.reset(wordId) }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Слово снова станет новым.")
        }
    }

    // MARK: Content

    private func header(_ word: Word) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                LevelChip(level: word.cefr)
                Text(word.list.title)
                    .font(Theme.Typography.small)
                    .foregroundStyle(Theme.textSecondary)
                if !word.headerDetail.isEmpty {
                    Text(word.headerDetail)
                        .accessibilityLabel(word.spokenHeaderDetail)
                        .font(Theme.Typography.small)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(word.lemma)
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityIdentifier("detailLemma")
                Button {
                    app.speech.speak(
                        word.lemma, accent: app.settings.values.speechAccent, speed: app.settings.values.speechSpeed)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundStyle(Theme.accent)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Озвучить")
            }
            if let ipa = word.ipa {
                Text(ipa)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.textSecondary)
            }
            Label(status.title, systemImage: status.symbol)
                .font(Theme.Typography.caption)
                .foregroundStyle(status.color)
                .accessibilityIdentifier("detailStatus")
        }
    }

    private func translations(_ word: Word) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(word.primaryTranslation)
                .font(Theme.Typography.cardTitle)
                .foregroundStyle(Theme.textPrimary)
            ForEach(Array(word.translations.dropFirst().enumerated()), id: \.offset) { _, extra in
                Text(extra)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private func example(_ word: Word) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let english = word.exampleEN {
                Text(ExampleHighlighter.attributed(english, lemma: word.lemma))
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.textPrimary)
            }
            if let russian = word.exampleRU {
                Text(russian)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(Theme.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { CardSurface() }
    }

    @ViewBuilder private var history: some View {
        if let progress, progress.status != .new || progress.timesSeen > 0 {
            VStack(alignment: .leading, spacing: 8) {
                Text("История")
                    .font(Theme.Typography.bodyEmphasized)
                    .foregroundStyle(Theme.textPrimary)
                historyRow("Показано раз", "\(progress.timesSeen)")
                if let first = progress.firstSeenAt {
                    historyRow("Впервые", first.formatted(date: .abbreviated, time: .omitted))
                }
                if let last = progress.lastSeenAt {
                    historyRow("Последний раз", last.formatted(date: .abbreviated, time: .omitted))
                }
                if progress.status == .review {
                    historyRow("Коробка", "\(progress.box) из \(LeitnerScheduler.intervals.count)")
                    if let due = progress.dueDayKey {
                        historyRow("Следующее повторение", dueText(due))
                    }
                }
                if progress.lapses > 0 {
                    historyRow("Забыто раз", "\(progress.lapses)")
                }
            }
            .padding(Theme.Spacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { CardSurface() }
        }
    }

    private func historyRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value).foregroundStyle(Theme.textPrimary)
        }
        .font(Theme.Typography.caption)
        .accessibilityElement(children: .combine)
    }

    private func dueText(_ due: DayKey) -> String {
        switch study.today.days(until: due) {
        case ..<1: "сегодня"
        case 1: "завтра"
        case let days: "через \(days) \(RussianPlural.form(days, one: "день", few: "дня", many: "дней"))"
        }
    }

    // MARK: Actions

    private func actions(_ word: Word) -> some View {
        VStack(spacing: Theme.Spacing.small) {
            if status == .known || status == .mastered || status == .review {
                Button("Вернуть в изучение") {
                    study.returnToLearning(wordId)
                }
                .buttonStyle(.pill(.secondary))
                .accessibilityIdentifier("returnToLearningButton")
            }
            if status != .known {
                Button("Уже знаю") { study.markKnown(wordId) }
                    .buttonStyle(.pill(.secondary))
                    .accessibilityIdentifier("markKnownButton")
            }
            if !study.plan.wordIds.contains(wordId), status != .known {
                Button("Добавить в сегодняшний набор") { study.addToToday(wordId) }
                    .buttonStyle(.pill(.primary))
                    .accessibilityIdentifier("addToTodayButton")
            }
            if status != .new {
                Button("Сбросить прогресс", role: .destructive) { confirmReset = true }
                    .buttonStyle(.pill(.secondary))
                    .accessibilityIdentifier("resetButton")
            }
        }
    }
}
