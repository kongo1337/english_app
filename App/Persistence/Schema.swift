import Foundation
import StudyCore
import SwiftData

/// Version 1 of the on-disk schema. Models are nested in the schema so that a later version
/// can keep its own copy of the classes and describe the migration between them.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [WordProgressEntity.self, DailyPlanEntity.self, ReviewLogEntity.self]
    }

    /// One row per word the user has ever touched. Words without a row are "new".
    @Model
    final class WordProgressEntity {
        @Attribute(.unique) var wordId: String
        var statusRaw: String
        var box: Int
        var dueDayKey: String?
        var firstSeenAt: Date?
        var lastSeenAt: Date?
        var timesSeen: Int
        var lapses: Int
        var isFavorite: Bool

        init(_ value: WordProgress) {
            wordId = value.wordId
            statusRaw = value.status.rawValue
            box = value.box
            dueDayKey = value.dueDayKey?.description
            firstSeenAt = value.firstSeenAt
            lastSeenAt = value.lastSeenAt
            timesSeen = value.timesSeen
            lapses = value.lapses
            isFavorite = value.isFavorite
        }

        func update(from value: WordProgress) {
            statusRaw = value.status.rawValue
            box = value.box
            dueDayKey = value.dueDayKey?.description
            firstSeenAt = value.firstSeenAt
            lastSeenAt = value.lastSeenAt
            timesSeen = value.timesSeen
            lapses = value.lapses
            isFavorite = value.isFavorite
        }

        var value: WordProgress {
            WordProgress(
                wordId: wordId, status: WordStatus(rawValue: statusRaw) ?? .new, box: box,
                dueDayKey: dueDayKey.flatMap { DayKey($0) }, firstSeenAt: firstSeenAt,
                lastSeenAt: lastSeenAt, timesSeen: timesSeen, lapses: lapses, isFavorite: isFavorite)
        }
    }

    /// The plan of one study day.
    @Model
    final class DailyPlanEntity {
        @Attribute(.unique) var dayKey: String
        var wordIds: [String]
        var queue: [String]
        var learnedIds: [String]
        var seenIds: [String]
        var extraBatches: Int
        var reviewTarget: Int

        init(_ value: DailyPlan) {
            dayKey = value.dayKey.description
            wordIds = value.wordIds
            queue = value.queue
            learnedIds = value.learnedIds.sorted()
            seenIds = value.seenIds.sorted()
            extraBatches = value.extraBatches
            reviewTarget = value.reviewTarget
        }

        func update(from value: DailyPlan) {
            wordIds = value.wordIds
            queue = value.queue
            learnedIds = value.learnedIds.sorted()
            seenIds = value.seenIds.sorted()
            extraBatches = value.extraBatches
            reviewTarget = value.reviewTarget
        }

        var value: DailyPlan? {
            guard let key = DayKey(dayKey) else { return nil }
            return DailyPlan(
                dayKey: key, wordIds: wordIds, queue: queue, learnedIds: Set(learnedIds),
                seenIds: Set(seenIds), extraBatches: extraBatches, reviewTarget: reviewTarget)
        }
    }

    /// Every learn/review answer, for statistics and backups.
    @Model
    final class ReviewLogEntity {
        var wordId: String
        var at: Date
        var dayKey: String
        var modeRaw: String
        var resultRaw: String

        init(_ value: ReviewLogEntry) {
            wordId = value.wordId
            at = value.at
            dayKey = value.dayKey.description
            modeRaw = value.mode.rawValue
            resultRaw = value.result.rawValue
        }

        var value: ReviewLogEntry? {
            guard let key = DayKey(dayKey), let mode = LogMode(rawValue: modeRaw),
                  let result = LogResult(rawValue: resultRaw)
            else { return nil }
            return ReviewLogEntry(wordId: wordId, at: at, dayKey: key, mode: mode, result: result)
        }
    }
}

typealias WordProgressEntity = SchemaV1.WordProgressEntity
typealias DailyPlanEntity = SchemaV1.DailyPlanEntity
typealias ReviewLogEntity = SchemaV1.ReviewLogEntity

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

enum Persistence {
    /// - Parameters:
    ///   - inMemory: used by previews and UI tests; nothing is written to disk.
    ///   - url: a custom store location (tests); nil means the app's default store.
    @MainActor
    static func makeContainer(inMemory: Bool = false, url: URL? = nil) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        } else if let url {
            configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        }
        return try ModelContainer(for: schema, migrationPlan: AppMigrationPlan.self, configurations: configuration)
    }
}
