import StudyCore
import SwiftUI

/// The Dictionaries tab: one card per Oxford list with its progress and an on/off switch.
struct DictionariesView: View {
    let app: AppEnvironment

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                    Text("Словари")
                        .font(Theme.Typography.screenTitle)
                        .foregroundStyle(Theme.textPrimary)
                        .accessibilityIdentifier("screen.dictionaries")
                    ForEach(WordList.allCases, id: \.self) { list in
                        DictionaryCard(app: app, list: list)
                    }
                    LevelCard(app: app)
                    Text("Выключенный словарь и слова ниже выбранного уровня сразу уходят из набора на сегодня, а в нём появляются подходящие. Прогресс этих слов сохраняется, а выученные слова продолжают приходить на повторение.")
                        .font(Theme.Typography.small)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, Theme.Spacing.screen)
                .padding(.top, Theme.Spacing.large)
                .padding(.bottom, Theme.Spacing.large)
            }
            .background(Theme.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct DictionaryCard: View {
    let app: AppEnvironment
    let list: WordList

    private var counts: StatusCounts {
        StatsCalculator.counts(app.study.catalog.words(in: list), progress: app.study.progress)
    }

    private var isEnabled: Bool { app.settings.values.study.enabledLists.contains(list) }
    private var isOnlyEnabled: Bool { isEnabled && app.settings.values.study.enabledLists.count == 1 }

    var body: some View {
        let counts = counts
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            NavigationLink {
                WordListView(app: app, list: list)
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(list.title)
                                .font(Theme.Typography.cardTitle)
                                .foregroundStyle(Theme.textPrimary)
                            Text(list.subtitle)
                                .font(Theme.Typography.small)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(Theme.textSecondary)
                            .accessibilityHidden(true)
                    }
                    StatusBar(counts: counts)
                    Text("Выучено \(counts.learned + counts.known) · учу \(counts.learning) · новых \(counts.new) · всего \(counts.total)")
                        .font(Theme.Typography.small)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("dictionaryCard.\(list.rawValue)")

            Toggle("Учить из этого словаря", isOn: toggleBinding)
                .font(Theme.Typography.body)
                .tint(Theme.accent)
                .disabled(isOnlyEnabled)
                .accessibilityIdentifier("dictionaryToggle.\(list.rawValue)")
        }
        .padding(Theme.Spacing.medium)
        .background { CardSurface() }
    }

    private var toggleBinding: Binding<Bool> {
        Binding(
            get: { isEnabled },
            set: { on in
                app.settings.update {
                    if on {
                        $0.study.enabledLists.insert(list)
                    } else if $0.study.enabledLists.count > 1 {
                        $0.study.enabledLists.remove(list)
                    }
                }
            })
    }
}

/// A three-part bar: learned, learning, new.
struct StatusBar: View {
    let counts: StatusCounts

    var body: some View {
        GeometryReader { proxy in
            let total = max(1, counts.total)
            let width = proxy.size.width
            HStack(spacing: 0) {
                Rectangle().fill(Theme.success).frame(width: width * CGFloat(counts.learned + counts.known) / CGFloat(total))
                Rectangle().fill(Theme.warning).frame(width: width * CGFloat(counts.learning) / CGFloat(total))
                Rectangle().fill(Theme.surfaceMuted)
            }
            .clipShape(Capsule())
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }
}

/// "Учить слова от уровня": words below the chosen level are not offered in the Learn tab.
private struct LevelCard: View {
    let app: AppEnvironment

    private var selected: CEFRLevel { app.settings.values.study.minLevel }
    private var available: Int {
        let settings = app.settings.values.study
        return app.study.catalog.words.filter { settings.allows($0) }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small + 4) {
            Text("Учить слова от уровня")
                .font(Theme.Typography.cardTitle)
                .foregroundStyle(Theme.textPrimary)
            HStack(spacing: 8) {
                ForEach(CEFRLevel.allCases, id: \.self) { level in
                    let isOn = level == selected
                    Button {
                        app.settings.update { $0.study.minLevel = level }
                    } label: {
                        Text(level.rawValue)
                            .font(Theme.Typography.bodyEmphasized)
                            .foregroundStyle(isOn ? Color.white : Theme.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(isOn ? Theme.accent : Theme.surfaceMuted, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                    .accessibilityLabel("Уровень \(level.rawValue)")
                    .accessibilityIdentifier("levelChip.\(level.rawValue)")
                }
            }
            Text(selected == .a1
                 ? "Сейчас учатся слова всех уровней: \(available)."
                 : "Слова уровня ниже \(selected.rawValue) не показываются. Подходит слов: \(available).")
                .font(Theme.Typography.small)
                .foregroundStyle(Theme.textSecondary)
                .accessibilityIdentifier("levelSummary")
        }
        .padding(Theme.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { CardSurface() }
    }
}
