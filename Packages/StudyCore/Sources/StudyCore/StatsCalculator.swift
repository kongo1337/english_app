import Foundation

/// What happened on one study day; the input of the streak.
public struct DaySummary: Equatable, Sendable {
    public let dayKey: DayKey
    public let planSize: Int
    public let learned: Int
    public let reviewTarget: Int
    public let reviewsAnswered: Int

    /// A day counts for the streak when at least 80 % of the plan was learned, or all the
    /// repetitions that were due when the day started were answered.
    public var isCompleted: Bool {
        let planDone = planSize > 0 && learned * 5 >= planSize * 4
        let reviewsDone = reviewTarget > 0 && reviewsAnswered >= reviewTarget
        return planDone || reviewsDone
    }
}

public struct StatusCounts: Equatable, Sendable {
    public var new = 0
    public var learning = 0
    public var review = 0
    public var mastered = 0
    public var known = 0

    public init() {}

    public var total: Int { new + learning + review + mastered + known }
    /// Words learned and not yet forgotten.
    public var learned: Int { review + mastered }

    mutating func add(_ status: WordStatus) {
        switch status {
        case .new: new += 1
        case .learning: learning += 1
        case .review: review += 1
        case .mastered: mastered += 1
        case .known: known += 1
        }
    }
}

public struct DayCount: Equatable, Sendable {
    public let dayKey: DayKey
    public let count: Int
}

public enum StatsCalculator {
    public static func summaries(plans: [DailyPlan], log: [ReviewLogEntry]) -> [DaySummary] {
        var reviews: [DayKey: Int] = [:]
        for entry in log where entry.mode == .review { reviews[entry.dayKey, default: 0] += 1 }
        return plans.map {
            DaySummary(
                dayKey: $0.dayKey, planSize: $0.wordIds.count, learned: $0.learnedIds.count,
                reviewTarget: $0.reviewTarget, reviewsAnswered: reviews[$0.dayKey] ?? 0)
        }
        .sorted { $0.dayKey < $1.dayKey }
    }

    /// Consecutive completed days up to today. Today not being finished yet does not break
    /// the streak: it is counted from yesterday until today is completed.
    public static func currentStreak(_ summaries: [DaySummary], today: DayKey) -> Int {
        let completed = Set(summaries.filter(\.isCompleted).map(\.dayKey))
        var day = completed.contains(today) ? today : today.adding(days: -1)
        var streak = 0
        while completed.contains(day) {
            streak += 1
            day = day.adding(days: -1)
        }
        return streak
    }

    public static func bestStreak(_ summaries: [DaySummary]) -> Int {
        let days = summaries.filter(\.isCompleted).map(\.dayKey).sorted()
        var best = 0, run = 0
        var previous: DayKey?
        for day in days {
            run = previous.map { $0.adding(days: 1) == day ? run + 1 : 1 } ?? 1
            best = max(best, run)
            previous = day
        }
        return best
    }

    public static func totals(catalog: WordCatalog, progress: [String: WordProgress]) -> StatusCounts {
        counts(catalog.words, progress: progress)
    }

    public static func counts(_ words: [Word], progress: [String: WordProgress]) -> StatusCounts {
        var result = StatusCounts()
        for word in words { result.add(progress[word.id]?.status ?? .new) }
        return result
    }

    public static func byLevel(
        catalog: WordCatalog, progress: [String: WordProgress]
    ) -> [CEFRLevel: StatusCounts] {
        Dictionary(uniqueKeysWithValues: CEFRLevel.allCases.map {
            ($0, counts(catalog.words(at: $0), progress: progress))
        })
    }

    public static func byList(
        catalog: WordCatalog, progress: [String: WordProgress]
    ) -> [WordList: StatusCounts] {
        Dictionary(uniqueKeysWithValues: WordList.allCases.map {
            ($0, counts(catalog.words(in: $0), progress: progress))
        })
    }

    /// Words learned per day for the last `days` days ending today, oldest first.
    public static func learnedPerDay(log: [ReviewLogEntry], today: DayKey, days: Int = 30) -> [DayCount] {
        var perDay: [DayKey: Int] = [:]
        for entry in log where entry.mode == .learn && entry.result == .learned {
            perDay[entry.dayKey, default: 0] += 1
        }
        return (0..<max(0, days)).map { offset in
            let day = today.adding(days: offset - days + 1)
            return DayCount(dayKey: day, count: perDay[day] ?? 0)
        }
    }

    /// Repetitions due on each of the next `days` days starting today; overdue words count
    /// for today.
    public static func reviewForecast(
        progress: [String: WordProgress], today: DayKey, days: Int = 7
    ) -> [Int] {
        var result = [Int](repeating: 0, count: max(0, days))
        for entry in progress.values where entry.status == .review {
            guard let due = entry.dueDayKey else { continue }
            let offset = max(0, today.days(until: due))
            if offset < result.count { result[offset] += 1 }
        }
        return result
    }
}
