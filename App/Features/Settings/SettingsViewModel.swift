import Foundation
import StudyCore
import SwiftUI

struct ExportItem: Identifiable {
    let id = UUID()
    let url: URL
}

/// State of the data section of Settings: export, import and reset.
@MainActor
@Observable
final class SettingsViewModel {
    private let app: AppEnvironment

    var exportItem: ExportItem?
    var showImporter = false
    var showImportConfirm = false
    var showResetFirst = false
    var showResetSecond = false
    var showDone = false
    var showError = false
    var doneMessage = ""
    var errorMessage = ""
    var pendingImport: AppBackup?

    init(app: AppEnvironment) {
        self.app = app
    }

    var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var pendingImportSummary: String {
        guard let backup = pendingImport else { return "" }
        let learned = backup.payload.progress.filter { $0.status != .new }.count
        let date = backup.exportedAt.formatted(date: .abbreviated, time: .shortened)
        return "Копия от \(date): \(RussianPlural.words(learned)) с прогрессом. Текущий прогресс будет заменён."
    }

    // MARK: Export

    func startExport() {
        do {
            exportItem = ExportItem(url: try app.backup.export())
        } catch {
            fail(BackupFailure.failed(String(describing: error)).message)
        }
    }

    // MARK: Import

    func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            fail(BackupFailure.failed(error.localizedDescription).message)
        case .success(let url):
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                pendingImport = try app.backup.read(try Data(contentsOf: url))
                showImportConfirm = true
            } catch let failure as BackupFailure {
                fail(failure.message)
            } catch {
                fail(BackupFailure.failed(error.localizedDescription).message)
            }
        }
    }

    func applyImport() {
        guard let backup = pendingImport else { return }
        pendingImport = nil
        do {
            try app.backup.apply(backup)
            doneMessage = "Прогресс восстановлен из копии."
            showDone = true
        } catch let failure as BackupFailure {
            fail(failure.message)
        } catch {
            fail(BackupFailure.failed(String(describing: error)).message)
        }
    }

    // MARK: Reset (two confirmations)

    func askReset() { showResetFirst = true }
    func confirmReset() { showResetSecond = true }

    func reset() {
        app.study.eraseAll()
        if let error = app.study.lastError {
            fail(BackupFailure.failed(error).message)
        } else {
            doneMessage = "Весь прогресс удалён."
            showDone = true
        }
    }

    private func fail(_ message: String) {
        errorMessage = message
        showError = true
    }
}
