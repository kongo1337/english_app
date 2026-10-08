import Charts
import StudyCore
import SwiftUI

/// The Progress tab: streak, totals, new words per day, levels, dictionaries, forecast.
struct ProgressScreen: View {
    let app: AppEnvironment

    var body: some View {
        let study = app.study
        let totals = StatsCalculator.totals(catalog: study.catalog, progress: study.progress)
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                Text("Прогресс")
                    .font(Theme.Typography.screenTitle)
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityIdentifier("screen.progress")

                streakCard(current: study.currentStreak(), best: study.bestStreak())
                totalsCard(totals)
                learnedChart(study.learnedPerDay(days: 30))
                levelsCard(StatsCalculator.byLevel(catalog: study.catalog, progress: study.progress))
                listsCard(StatsCalculator.byList(catalog: study.catalog, progress: study.progress))
                forecastCard(StatsCalculator.reviewForecast(progress: study.progress, today: study.today))
            }
            .padding(.horizontal, Theme.Spacing.screen)
            .padding(.vertical, Theme.Spacing.large)
        }
        .background(Theme.bg.ignoresSafeArea())
    }

    // MARK: Cards

    private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small + 4) {
            Text(title)
                .font(Theme.Typography.bodyEmphasized)
                .foregroundStyle(Theme.textPrimary)
            content()
        }
        .padding(Theme.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { CardSurface() }
    }

    private func streakCard(current: Int, best: Int) -> some View {
        HStack(spacing: Theme.Spacing.medium) {
            Image(systemName: "flame.fill")
                .font(.system(size: 34))
                .foregroundStyle(current > 0 ? Theme.badge : Theme.textSecondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(ProgressTexts.streak(current))
                    .font(Theme.Typography.cardTitle)
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityIdentifier("streakText")
                Text("Лучшая серия: \(best) \(RussianPlural.form(best, one: "день", few: "дня", many: "дней"))")
                    .font(Theme.Typography.small)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .padding(Theme.Spacing.medium)
        .background { CardSurface() }
    }

    private func totalsCard(_ totals: StatusCounts) -> some View {
        card("Итоги") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 12) {
                stat("Выучено", totals.learned, Theme.success)
                stat("На повторении", totals.review, Theme.accent)
                stat("Освоено", totals.mastered, Theme.success)
                stat("Уже знаю", totals.known, Theme.textSecondary)
                stat("Учу", totals.learning, Theme.warning)
                stat("Новых", totals.new, Theme.textSecondary)
            }
        }
    }

    private func stat(_ title: String, _ value: Int, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(title)
                .font(Theme.Typography.small)
                .foregroundStyle(Theme.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func learnedChart(_ days: [DayCount]) -> some View {
        card("Выучено новых слов за 30 дней") {
            Chart(days, id: \.dayKey) { item in
                BarMark(x: .value("День", item.dayKey.daysSinceEpoch), y: .value("Слов", item.count))
                    .foregroundStyle(Theme.accent)
                    .cornerRadius(2)
            }
            .chartXAxis(.hidden)
            .frame(height: 140)
            .accessibilityLabel("График выученных слов по дням")
            .accessibilityValue("Всего за период: \(days.map(\.count).reduce(0, +))")
        }
    }

    private func levelsCard(_ byLevel: [CEFRLevel: StatusCounts]) -> some View {
        card("По уровням") {
            ForEach(CEFRLevel.allCases, id: \.self) { level in
                let counts = byLevel[level] ?? StatusCounts()
                if counts.total > 0 { breakdownRow(title: level.rawValue, counts: counts, tint: Theme.level(level)) }
            }
        }
    }

    private func listsCard(_ byList: [WordList: StatusCounts]) -> some View {
        card("По словарям") {
            ForEach(WordList.allCases, id: \.self) { list in
                breakdownRow(title: list.title, counts: byList[list] ?? StatusCounts(), tint: Theme.accent)
            }
        }
    }

    private func breakdownRow(title: String, counts: StatusCounts, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(Theme.Typography.caption).foregroundStyle(tint)
                Spacer()
                Text("\(counts.learned + counts.known) из \(counts.total)")
                    .font(Theme.Typography.small)
                    .foregroundStyle(Theme.textSecondary)
            }
            StatusBar(counts: counts)
        }
        .accessibilityElement(children: .combine)
    }

    private func forecastCard(_ forecast: [Int]) -> some View {
        card("Повторения на 7 дней") {
            Chart(Array(forecast.enumerated()), id: \.offset) { item in
                BarMark(x: .value("День", ProgressTexts.dayLabel(item.offset)), y: .value("Слов", item.element))
                    .foregroundStyle(Theme.accent)
                    .cornerRadius(3)
                    .annotation(position: .top) {
                        if item.element > 0 {
                            Text("\(item.element)").font(Theme.Typography.small).foregroundStyle(Theme.textSecondary)
                        }
                    }
            }
            .frame(height: 140)
            .accessibilityLabel("Прогноз повторений")
            .accessibilityValue(forecast.map(String.init).joined(separator: ", "))
        }
    }
}
