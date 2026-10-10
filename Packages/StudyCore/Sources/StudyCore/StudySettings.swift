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
    /// CEFR levels offered in "Учить". All five by default; never empty.
    public var levels: Set<CEFRLevel>

    public init(
        newWordsPerDay: Int = 60, carryoverBuffer: Int = 20,
        enabledLists: Set<WordList> = Set(WordList.allCases), order: StudyOrderMode = .byLevel,
        reviewLimit: Int? = nil, seed: UInt64 = 0x5EED, dayStartHour: Int = 4, extraBatchSize: Int = 10,
        levels: Set<CEFRLevel> = Set(CEFRLevel.allCases)
    ) {
        self.newWordsPerDay = newWordsPerDay
        self.carryoverBuffer = carryoverBuffer
        self.enabledLists = enabledLists
        self.order = order
        self.reviewLimit = reviewLimit
        self.seed = seed
        self.dayStartHour = dayStartHour
        self.extraBatchSize = extraBatchSize
        self.levels = levels.isEmpty ? Set(CEFRLevel.allCases) : levels
    }

    /// Whether a word may be studied under the current dictionary and level choice.
    /// Progress is never touched by this: words outside the filter simply are not offered.
    public func allows(_ word: Word) -> Bool {
        enabledLists.contains(word.list) && levels.contains(word.cefr)
    }

    /// True when only some of the levels are chosen. The chosen levels are then mixed together.
    public var choosesSomeLevels: Bool { levels.count < CEFRLevel.allCases.count }

    // Settings written by an older version lack the newer keys: they get the defaults, and the
    // user's other choices (and the random seed!) survive.
    private enum CodingKeys: String, CodingKey {
        case newWordsPerDay, carryoverBuffer, enabledLists, order, reviewLimit, seed
        case dayStartHour, extraBatchSize, levels
    }

    /// Read only: the single minimum level that an earlier version saved.
    private enum LegacyKeys: String, CodingKey { case minLevel }

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
        if let chosen = try c.decodeIfPresent(Set<CEFRLevel>.self, forKey: .levels), !chosen.isEmpty {
            levels = chosen
        } else if let minimum = try decoder.container(keyedBy: LegacyKeys.self)
            .decodeIfPresent(CEFRLevel.self, forKey: .minLevel)
        {
            levels = Set(CEFRLevel.allCases.filter { $0 >= minimum })
        } else {
            levels = d.levels
        }
    }
}
