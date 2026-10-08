import SwiftUI

/// What the buttons and gestures do. Opens by itself on the first launch.
struct HelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.large) {
                    item("hand.tap", "Нажмите на карточку", "Она перевернётся и покажет перевод и пример. Слово можно озвучить кнопкой с динамиком.")
                    item("checkmark", "Выучил", "Слово уйдёт на повторение: завтра, потом через 3, 7, 14, 30 и 60 дней. Свайп вправо делает то же самое.")
                    item("arrow.triangle.2.circlepath", "Ещё учу", "Слово вернётся через несколько карточек и завтра, пока вы его не выучите. Свайп влево.")
                    item("arrow.uturn.backward", "Отмена", "Стрелка вверху отменяет последнее действие (до 10 шагов).")
                    item("checkmark.seal", "Уже знаю", "В меню «⋯» на карточке: слово исчезнет и больше не появится.")
                    item("arrow.left.arrow.right", "EN-RU / RU-EN", "Переключает направление: видите английское слово и вспоминаете перевод или наоборот.")
                    item("calendar", "План на день", "Каждый день в плане новые слова и слова «ещё учу» с прошлых дней. День начинается в 4 утра.")
                }
                .padding(Theme.Spacing.screen)
            }
            .background(Theme.bg)
            .navigationTitle("Как это работает")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Понятно") { dismiss() }
                        .accessibilityIdentifier("helpDone")
                }
            }
        }
        .presentationDetents([.large])
        .accessibilityIdentifier("helpSheet")
    }

    private func item(_ symbol: String, _ title: LocalizedStringKey, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.medium) {
            Image(systemName: symbol)
                .font(.system(.title3, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 36, height: 36)
                .background(Theme.surfaceMuted, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Theme.Typography.bodyEmphasized)
                    .foregroundStyle(Theme.textPrimary)
                Text(text)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
