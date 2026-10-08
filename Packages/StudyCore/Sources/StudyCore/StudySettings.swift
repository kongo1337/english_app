import Foundation

public enum StudyOrderMode: String, Codable, CaseIterable, Sendable {
    /// Oxford 3000 first, then 5000; inside a list A1 → C1; inside a level in a stable random order.
    case byLevel
    /// Stable random order across all enabled lists.
    case random
    /// Alphabetical.
    case alphabetical
}

/// The settings that influence which cards are studied. UI-only settings (theme, speech,
/// notifications) live in the app target.
public struct StudySettings: Codable, Equatable, Sendable {
    /// New words per day (N).
    public var newWordsPerDay: Int
    /// How far the carry-over may push the daily plan above N (B).
    public var carryoverBuffer: Int
    public var enabledLists: Set<WordList>
    public var order: StudyOrderMode
    /// Maximum repetitions per day; nil means unlimited.
    public var reviewLimit: Int?
    /// Seed of the stable random order, generated once per installation.
    public var seed: UInt64
    public var dayStartHour: Int
    /// How many new words the "more words" button adds.
    public var extraBatchSize: Int

    public init(
        newWordsPerDay: Int = 60, carryoverBuffer: Int = 20,
        enabledLists: Set<WordList> = Set(WordList.allCases), order: StudyOrderMode = .byLevel,
        reviewLimit: Int? = nil, seed: UInt64 = 0x5EED, dayStartHour: Int = 4, extraBatchSize: Int = 10
    ) {
        self.newWordsPerDay = newWordsPerDay
        self.carryoverBuffer = carryoverBuffer
        self.enabledLists = enabledLists
        self.order = order
        self.reviewLimit = reviewLimit
        self.seed = seed
        self.dayStartHour = dayStartHour
        self.extraBatchSize = extraBatchSize
    }
}
