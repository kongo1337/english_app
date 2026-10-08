import Foundation
import StudyCore

typealias AppBackup = BackupFile<UserSettings>

enum BackupFailure: Error, Equatable {
    case unreadable
    case newerFormat
    case failed(String)

    var message: String {
        switch self {
        case .unreadable: "Этот файл не похож на резервную копию English Cards."
        case .newerFormat: "Файл создан более новой версией приложения. Обновите приложение."
        case .failed(let reason): "Не удалось выполнить операцию: \(reason)"
        }
    }
}

/// Export and import of the whole progress as one JSON file.
@MainActor
final class BackupService {
    private let study: StudyService
    private let settings: SettingsStore
    private let now: @MainActor () -> Date

    init(study: StudyService, settings: SettingsStore, now: @escaping @MainActor () -> Date) {
        self.study = study
        self.settings = settings
        self.now = now
    }

    /// Writes the backup to a temporary file that can be handed to the share sheet.
    func export() throws -> URL {
        let backup = AppBackup(
            exportedAt: now(), dictionaryVersion: study.catalog.version, settings: settings.values,
            payload: try study.snapshot())
        let data = try backup.encoded()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("english-cards-\(study.today).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Reads and checks a file; nothing changes until `apply` is called.
    func read(_ data: Data) throws -> AppBackup {
        do {
            return try AppBackup.decode(data)
        } catch BackupError.unsupportedFormat {
            throw BackupFailure.newerFormat
        } catch {
            throw BackupFailure.unreadable
        }
    }

    /// Replaces the current progress and settings with the backup.
    func apply(_ backup: AppBackup) throws {
        guard study.restore(backup.payload) else {
            throw BackupFailure.failed(study.lastError ?? "")
        }
        var restored = backup.settings
        restored.hasSeenHelp = true
        settings.update { $0 = restored }
    }
}
