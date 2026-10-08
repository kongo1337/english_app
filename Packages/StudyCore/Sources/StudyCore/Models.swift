import Foundation

// MARK: - Dictionary entries

public enum CEFRLevel: String, Codable, CaseIterable, Comparable, Sendable {
    case a1 = "A1", a2 = "A2", b1 = "B1", b2 = "B2", c1 = "C1"

    public var rank: Int {
        switch self {
        case .a1: 0
        case .a2: 1
        case .b1: 2
        case .b2: 3
        case .c1: 4
        }
    }

    public static func < (lhs: CEFRLevel, rhs: CEFRLevel) -> Bool { lhs.rank < rhs.rank }
}

public enum WordList: String, Codable, CaseIterable, Comparable, Sendable {
    case ox3000, ox5000

    public var rank: Int { self == .ox3000 ? 0 : 1 }

    public static func < (lhs: WordList, rhs: WordList) -> Bool { lhs.rank < rhs.rank }
}

public enum PartOfSpeech: String, Codable, CaseIterable, Sendable {
    case noun, verb, adjective, adverb, preposition, conjunction, pronoun
    case determiner, number, exclamation, modal, auxiliary, article, other
}

/// One card of the dictionary: a lemma in a single part of speech (and, for homonyms, a single sense).
public struct Word: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let lemma: String
    /// Disambiguation from the Oxford list, e.g. "money" for `bank (money)`.
    public let sense: String?
    public let pos: PartOfSpeech
    public let cefr: CEFRLevel
    public let list: WordList
    public let ipa: String?
    /// 1–3 groups of meanings, the first one is the main translation.
    public let translations: [String]
    public let exampleEN: String?
    public let exampleRU: String?
    /// Order of the word inside its list (level, then alphabet).
    public let order: Int

    public init(
        id: String, lemma: String, sense: String? = nil, pos: PartOfSpeech, cefr: CEFRLevel,
        list: WordList, ipa: String? = nil, translations: [String], exampleEN: String? = nil,
        exampleRU: String? = nil, order: Int
    ) {
        self.id = id
        self.lemma = lemma
        self.sense = sense
        self.pos = pos
        self.cefr = cefr
        self.list = list
        self.ipa = ipa
        self.translations = translations
        self.exampleEN = exampleEN
        self.exampleRU = exampleRU
        self.order = order
    }

    public var primaryTranslation: String { translations.first ?? "" }
}

// MARK: - Progress

public enum WordStatus: String, Codable, Sendable {
    /// Never shown, or progress was reset.
    case new
    /// Pressed "still learning" (or "forgot"): returns in the daily plan until learned.
    case learning
    /// Learned, waits for spaced repetition.
    case review
    /// Passed every repetition interval.
    case mastered
    /// The user already knew it; never shown again.
    case known
}

public struct WordProgress: Codable, Equatable, Sendable {
    public let wordId: String
    public var status: WordStatus
    /// Leitner box: 0 for learning/new, 1…6 for review.
    public var box: Int
    public var dueDayKey: DayKey?
    public var firstSeenAt: Date?
    public var lastSeenAt: Date?
    public var timesSeen: Int
    public var lapses: Int
    public var isFavorite: Bool

    public init(
        wordId: String, status: WordStatus = .new, box: Int = 0, dueDayKey: DayKey? = nil,
        firstSeenAt: Date? = nil, lastSeenAt: Date? = nil, timesSeen: Int = 0, lapses: Int = 0,
        isFavorite: Bool = false
    ) {
        self.wordId = wordId
        self.status = status
        self.box = box
        self.dueDayKey = dueDayKey
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
        self.timesSeen = timesSeen
        self.lapses = lapses
        self.isFavorite = isFavorite
    }

    public static func fresh(_ wordId: String) -> WordProgress { WordProgress(wordId: wordId) }

    /// Words forgotten three or more times are shown as "hard".
    public var isHard: Bool { lapses >= 3 }
}

// MARK: - Daily plan

public struct DailyPlan: Codable, Equatable, Sendable {
    public let dayKey: DayKey
    /// Carry-over words first, then new ones. Words marked "already known" are removed.
    public var wordIds: [String]
    /// Cards still to be shown, the first one is on screen.
    public var queue: [String]
    public var learnedIds: Set<String>
    /// Cards shown in the current round (a round ends when only seen cards are left).
    public var seenIds: Set<String>
    /// How many times "10 more words" was pressed.
    public var extraBatches: Int
    /// How many repetitions were due when the plan was created (used for the streak).
    public var reviewTarget: Int

    public init(
        dayKey: DayKey, wordIds: [String], queue: [String]? = nil, learnedIds: Set<String> = [],
        seenIds: Set<String> = [], extraBatches: Int = 0, reviewTarget: Int = 0
    ) {
        self.dayKey = dayKey
        self.wordIds = wordIds
        self.queue = queue ?? wordIds
        self.learnedIds = learnedIds
        self.seenIds = seenIds
        self.extraBatches = extraBatches
        self.reviewTarget = reviewTarget
    }

    public var currentWordId: String? { queue.first }
    public var learnedCount: Int { learnedIds.count }
    public var totalCount: Int { wordIds.count }
}

// MARK: - Log

public enum LogMode: String, Codable, Sendable { case learn, review, manual }

public enum LogResult: String, Codable, Sendable {
    case learned, stillLearning, known, remembered, forgot, reset, returnedToLearning
}

public struct ReviewLogEntry: Codable, Equatable, Sendable {
    public let wordId: String
    public let at: Date
    public let dayKey: DayKey
    public let mode: LogMode
    public let result: LogResult

    public init(wordId: String, at: Date, dayKey: DayKey, mode: LogMode, result: LogResult) {
        self.wordId = wordId
        self.at = at
        self.dayKey = dayKey
        self.mode = mode
        self.result = result
    }

    public var key: LogKey { LogKey(wordId: wordId, at: at) }
}

public struct LogKey: Hashable, Codable, Sendable {
    public let wordId: String
    public let at: Date

    public init(wordId: String, at: Date) {
        self.wordId = wordId
        self.at = at
    }
}
