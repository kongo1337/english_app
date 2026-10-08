import Foundation

/// The learning data that goes into a backup file. The app adds its own settings around it.
public struct BackupPayload: Codable, Equatable, Sendable {
    public var progress: [WordProgress]
    public var plans: [DailyPlan]
    public var log: [ReviewLogEntry]

    public init(progress: [WordProgress] = [], plans: [DailyPlan] = [], log: [ReviewLogEntry] = []) {
        self.progress = progress
        self.plans = plans
        self.log = log
    }
}

private struct BackupHeader: Decodable { let format: Int }

public enum BackupError: Error, Equatable, Sendable {
    /// The file is not a backup of this app (or is damaged).
    case unreadable
    /// Written by a newer version of the app.
    case unsupportedFormat(Int)
}

/// The envelope of a backup file: `{ "format", "exportedAt", "dictionaryVersion", "settings", "progress", "plans", "log" }`.
///
/// `Settings` is the app's settings type; the core only carries it through.
public struct BackupFile<Settings: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    public static var currentFormat: Int { 1 }

    public var format: Int
    public var exportedAt: Date
    public var dictionaryVersion: Int
    public var settings: Settings
    public var payload: BackupPayload

    public init(exportedAt: Date, dictionaryVersion: Int, settings: Settings, payload: BackupPayload) {
        format = Self.currentFormat
        self.exportedAt = exportedAt
        self.dictionaryVersion = dictionaryVersion
        self.settings = settings
        self.payload = payload
    }

    private enum CodingKeys: String, CodingKey {
        case format, exportedAt, dictionaryVersion, settings, progress, plans, log
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        format = try c.decode(Int.self, forKey: .format)
        exportedAt = try c.decode(Date.self, forKey: .exportedAt)
        dictionaryVersion = try c.decode(Int.self, forKey: .dictionaryVersion)
        settings = try c.decode(Settings.self, forKey: .settings)
        payload = BackupPayload(
            progress: try c.decode([WordProgress].self, forKey: .progress),
            plans: try c.decode([DailyPlan].self, forKey: .plans),
            log: try c.decode([ReviewLogEntry].self, forKey: .log))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(format, forKey: .format)
        try c.encode(exportedAt, forKey: .exportedAt)
        try c.encode(dictionaryVersion, forKey: .dictionaryVersion)
        try c.encode(settings, forKey: .settings)
        try c.encode(payload.progress, forKey: .progress)
        try c.encode(payload.plans, forKey: .plans)
        try c.encode(payload.log, forKey: .log)
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    /// Reads and checks a backup file. Progress of words missing from the current dictionary
    /// is kept (it may come back with a newer dictionary version).
    public static func decode(_ data: Data) throws -> BackupFile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        // The format number is checked first so that a newer file gives a precise error.
        guard let header = try? decoder.decode(BackupHeader.self, from: data) else { throw BackupError.unreadable }
        guard header.format <= currentFormat else { throw BackupError.unsupportedFormat(header.format) }
        guard let file = try? decoder.decode(BackupFile.self, from: data) else { throw BackupError.unreadable }
        guard file.payload.progress.allSatisfy({ (0...6).contains($0.box) }) else { throw BackupError.unreadable }
        return file
    }
}
