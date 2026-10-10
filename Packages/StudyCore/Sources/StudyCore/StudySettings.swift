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
    /// Words below this CEFR level are not offered in "Учить" (A1 = everything).
    public var minLevel: CEFRLevel

    public init(
        newWordsPerDay: Int = 60, carryoverBuffer: Int = 20,
        enabledLists: Set<WordList> = Set(WordList.allCases), order: StudyOrderMode = .byLevel,
        reviewLimit: Int? = nil, seed: UInt64 = 0x5EED, dayStartHour: Int = 4, extraBatchSize: Int = 10,
        minLevel: CEFRLevel = .a1
    ) {
        self.newWordsPerDay = newWordsPerDay
        self.carryoverBuffer = carryoverBuffer
        self.enabledLists = enabledLists
        self.order = order
        self.reviewLimit = reviewLimit
        self.seed = seed
        self.dayStartHour = dayStartHour
        self.extraBatchSize = extraBatchSize
        self.minLevel = minLevel
    }

    /// Whether a word may be studied under the current dictionary and level choice.
    /// Progress is never touched by this: words outside the filter simply are not offered.
    public func allows(_ word: Word) -> Bool {
        enabledLists.contains(word.list) && word.cefr >= minLevel
    }

    // Settings written by an older version lack the newer keys: they get the defaults, and the
    // user's other choices (and the random seed!) survive.
    private enum CodingKeys: String, CodingKey {
        case newWordsPerDay, carryoverBuffer, enabledLists, order, reviewLimit, seed
        case dayStartHour, extraBatchSize, minLevel
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = StudySettings()
        newWordsPerDay = try c.decodeIfPresent(Int.self, forKey: .newWordsPerDay) ?? d.newWordsPerDay
        carryoverBuffer = try c.decodeIfPresent(Int.self, forKey: .carryoverBuffer) ?? d.carryoverBuffer
        enabledLists = try c.decodeIfPresent(Set<WordList>.self, forKey: .enabledLists) ?? d.enabledLists
        order = try c.decodeIfPresent(StudyOrderMode.self, forKey: .order) ?? d.order
        reviewLimit = try c.decodeIfPresent(Int.self, forKey: .reviewLimit)
        seed = try c.decodeIfPresent(UInt64.self, forKey: .seed) ?? d.seed
        dayStartHour = try c.decodeIfPresent(Int.self, forKey: .dayStartHour) ?? d.dayStartHour
        extraBatchSize = try c.decodeIfPresent(Int.self, forKey: .extraBatchSize) ?? d.extraBatchSize
        minLevel = try c.decodeIfPresent(CEFRLevel.self, forKey: .minLevel) ?? d.minLevel
    }
}
