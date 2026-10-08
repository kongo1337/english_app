import Foundation

public enum ReviewAnswer: Equatable, Sendable { case remembered, forgot }

/// Spaced repetition with six Leitner boxes.
public enum LeitnerScheduler {
    /// Days until the next showing, for boxes 1…6.
    public static let intervals = [1, 3, 7, 14, 30, 60]
    public static var lastBox: Int { intervals.count }

    /// Days between a successful answer and the next showing when the word sits in `box`.
    public static func interval(forBox box: Int) -> Int? {
        (1...lastBox).contains(box) ? intervals[box - 1] : nil
    }

    /// "Learned" in the Learn tab: the word enters box 1 and is due tomorrow.
    public static func learned(_ progress: WordProgress, today: DayKey, now: Date) -> WordProgress {
        var next = seen(progress, now: now)
        next.status = .review
        next.box = 1
        next.dueDayKey = today.adding(days: intervals[0])
        return next
    }

    /// "Still learning" in the Learn tab.
    public static func stillLearning(_ progress: WordProgress, now: Date) -> WordProgress {
        var next = seen(progress, now: now)
        next.status = .learning
        next.box = 0
        next.dueDayKey = nil
        return next
    }

    /// "Remembered" / "Forgot" in the Review tab.
    public static func answer(
        _ answer: ReviewAnswer, to progress: WordProgress, today: DayKey, now: Date
    ) -> WordProgress {
        var next = seen(progress, now: now)
        switch answer {
        case .forgot:
            next.status = .learning
            next.box = 0
            next.dueDayKey = nil
            next.lapses += 1
        case .remembered:
            let box = max(1, progress.box) + 1
            if box > lastBox {
                next.status = .mastered
                next.box = lastBox
                next.dueDayKey = nil
            } else {
                next.status = .review
                next.box = box
                next.dueDayKey = today.adding(days: intervals[box - 1])
            }
        }
        return next
    }

    private static func seen(_ progress: WordProgress, now: Date) -> WordProgress {
        var next = progress
        next.firstSeenAt = progress.firstSeenAt ?? now
        next.lastSeenAt = now
        next.timesSeen += 1
        return next
    }
}

/// Builds the list of words to repeat today.
public enum ReviewQueueBuilder {
    /// Words whose due day has come, the most overdue first. Words in `excluding` (today's
    /// plan) are shown in the Learn tab only.
    ///
    /// - Parameters:
    ///   - answeredToday: repetitions already answered today, counted against `limit`.
    ///   - limit: maximum repetitions per day, nil for unlimited.
    public static func queue(
        catalog: WordCatalog, progress: [String: WordProgress], today: DayKey,
        excluding: Set<String> = [], answeredToday: Int = 0, limit: Int? = nil
    ) -> [String] {
        let due = progress.values
            .filter { entry in
                guard entry.status == .review, let due = entry.dueDayKey else { return false }
                return due <= today && catalog.contains(entry.wordId) && !excluding.contains(entry.wordId)
            }
            .sorted { lhs, rhs in
                lhs.dueDayKey == rhs.dueDayKey
                    ? lhs.wordId < rhs.wordId
                    : (lhs.dueDayKey ?? today) < (rhs.dueDayKey ?? today)
            }
            .map(\.wordId)
        guard let limit else { return due }
        return Array(due.prefix(max(0, limit - answeredToday)))
    }
}
