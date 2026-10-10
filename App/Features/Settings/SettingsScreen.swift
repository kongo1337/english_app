import StudyCore
import SwiftUI
import UniformTypeIdentifiers

/// The Settings tab: study, speech, reminders, theme, backup and reset.
struct SettingsScreen: View {
    let app: AppEnvironment

    @State private var model: SettingsViewModel

    init(app: AppEnvironment) {
        self.app = app
        _model = State(initialValue: SettingsViewModel(app: app))
    }

    private var settings: SettingsStore { app.settings }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Настройки")
                .font(Theme.Typography.screenTitle)
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, Theme.Spacing.screen)
                .padding(.top, Theme.Spacing.small)
                .padding(.bottom, Theme.Spacing.small)
                .accessibilityIdentifier("screen.settings")
            Form {
                studySection
                speechSection
                reminderSection
                appearanceSection
                dataSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
        }
        .background(Theme.bg.ignoresSafeArea())
        .modifier(BackupDialogs(model: model))
    }

    // MARK: Sections

    private var studySection: some View {
        Section {
            Stepper(
                value: settings.binding(\.study.newWordsPerDay), in: 10...100, step: 5
            ) {
                row("Новых слов в день", "\(settings.values.study.newWordsPerDay)")
            }
            .accessibilityIdentifier("newWordsStepper")

            Stepper(value: settings.binding(\.study.carryoverBuffer), in: 0...60, step: 5) {
                row("Буфер повторов «ещё учу»", "\(settings.values.study.carryoverBuffer)")
            }

            Picker("Порядок новых слов", selection: settings.binding(\.study.order)) {
                Text("По уровню").tag(StudyOrderMode.byLevel)
                Text("Вперемешку").tag(StudyOrderMode.random)
                Text("По алфавиту").tag(StudyOrderMode.alphabetical)
            }

            Picker("Направление", selection: settings.binding(\.direction)) {
                Text("EN → RU").tag(CardDirection.enToRu)
                Text("RU → EN").tag(CardDirection.ruToEn)
            }

            Picker("Начало учебного дня", selection: settings.binding(\.study.dayStartHour)) {
                ForEach(0...6, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) }
            }

            Picker("Лимит повторений в день", selection: settings.binding(\.study.reviewLimit)) {
                Text("Без лимита").tag(Int?.none)
                ForEach([50, 100, 200], id: \.self) { Text("\($0)").tag(Int?.some($0)) }
            }
        } header: {
            Text("Учёба")
        } footer: {
            Text("Размер набора и порядок действуют с завтрашнего дня. Словари и уровни слов меняют набор сразу, их выбирают на вкладке «Словари».")
        }
    }

    private var speechSection: some View {
        Section("Озвучка и отклик") {
            Picker("Акцент", selection: settings.binding(\.speechAccent)) {
                Text("Американский").tag(SpeechAccent.us)
                Text("Британский").tag(SpeechAccent.uk)
            }
            Picker("Скорость", selection: settings.binding(\.speechSpeed)) {
                Text("Нормально").tag(SpeechSpeed.normal)
                Text("Медленно").tag(SpeechSpeed.slow)
            }
            Toggle("Озвучивать слово автоматически", isOn: settings.binding(\.autoSpeak))
            Toggle("Тактильный отклик", isOn: settings.binding(\.haptics))
        }
    }

    private var reminderSection: some View {
        Section {
            Toggle("Напоминание", isOn: settings.binding(\.reminderEnabled))
                .accessibilityIdentifier("reminderToggle")
            if settings.values.reminderEnabled {
                DatePicker("Время", selection: reminderTime, displayedComponents: .hourAndMinute)
            }
        } footer: {
            Text("Напоминание не приходит, если набор на сегодня уже пройден. Разрешение на уведомления спросим после первого законченного занятия.")
        }
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: settings.values.reminderHour, minute: settings.values.reminderMinute,
                    second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                settings.update {
                    $0.reminderHour = parts.hour ?? 19
                    $0.reminderMinute = parts.minute ?? 0
                }
            })
    }

    private var appearanceSection: some View {
        Section("Оформление") {
            Picker("Тема", selection: settings.binding(\.theme)) {
                Text("Как в системе").tag(ThemeChoice.system)
                Text("Светлая").tag(ThemeChoice.light)
                Text("Тёмная").tag(ThemeChoice.dark)
            }
        }
    }

    private var dataSection: some View {
        Section {
            Button("Экспортировать прогресс") { model.startExport() }
                .accessibilityIdentifier("exportButton")
            Button("Импортировать из файла") { model.showImporter = true }
                .accessibilityIdentifier("importButton")
            Button("Сбросить весь прогресс", role: .destructive) { model.askReset() }
                .accessibilityIdentifier("resetAllButton")
        } header: {
            Text("Данные")
        } footer: {
            Text("Файл с прогрессом можно сохранить в «Файлы» и открыть на другом телефоне.")
        }
    }

    private var aboutSection: some View {
        Section("О приложении") {
            row("Версия", model.appVersion)
            row("Версия словаря", "\(app.catalog.version)")
            row("Слов в словарях", "\(app.catalog.count)")
            Text("Списки слов Oxford 3000 и Oxford 5000 принадлежат Oxford University Press и используются в личных целях. Переводы и примеры подготовлены для этого приложения.")
                .font(Theme.Typography.small)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(Theme.textSecondary)
        }
    }
}

/// Export sheet, file importer, and the confirmation dialogs of import and reset.
private struct BackupDialogs: ViewModifier {
    @Bindable var model: SettingsViewModel

    func body(content: Content) -> some View {
        content
            .sheet(item: $model.exportItem) { item in
                ActivityView(url: item.url)
                    .presentationDetents([.medium, .large])
            }
            .fileImporter(isPresented: $model.showImporter, allowedContentTypes: [.json]) { result in
                model.handleImport(result)
            }
            .confirmationDialog(
                "Заменить текущий прогресс копией из файла?", isPresented: $model.showImportConfirm,
                titleVisibility: .visible
            ) {
                Button("Заменить", role: .destructive) { model.applyImport() }
                Button("Отмена", role: .cancel) { model.pendingImport = nil }
            } message: {
                Text(model.pendingImportSummary)
            }
            .confirmationDialog(
                "Сбросить весь прогресс?", isPresented: $model.showResetFirst, titleVisibility: .visible
            ) {
                Button("Сбросить…", role: .destructive) { model.confirmReset() }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Все выученные слова, серия и статистика будут удалены.")
            }
            .alert("Точно удалить всё?", isPresented: $model.showResetSecond) {
                Button("Удалить навсегда", role: .destructive) { model.reset() }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Отменить это действие нельзя. Сначала можно сделать экспорт.")
            }
            .alert("Готово", isPresented: $model.showDone) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(model.doneMessage)
            }
            .alert("Ошибка", isPresented: $model.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(model.errorMessage)
            }
    }
}

/// The system share sheet for one file.
private struct ActivityView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
