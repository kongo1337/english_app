import Foundation

/// Manual changes to a word's progress from the dictionary screens.
public enum ProgressRules {
    /// "Уже знаю": the word is excluded from everything.
    public static func markKnown(_ progress: WordProgress, now: Date) -> WordProgress {
        var next = progress
        next.firstSeenAt = progress.firstSeenAt ?? now
        next.lastSeenAt = now
        next.status = .known
        next.box = 0
        next.dueDayKey = nil
        return next
    }

    /// "Вернуть в изучение": the word joins tomorrow's carry-over.
    public static func returnToLearning(_ progress: WordProgress, now: Date) -> WordProgress {
        var next = progress
        next.firstSeenAt = progress.firstSeenAt ?? now
        next.lastSeenAt = now
        next.status = .learning
        next.box = 0
        next.dueDayKey = nil
        return next
    }

    /// "Сбросить прогресс": back to a never-seen word (the favourite mark is kept).
    public static func reset(_ progress: WordProgress) -> WordProgress {
        WordProgress(wordId: progress.wordId, isFavorite: progress.isFavorite)
    }

    public static func toggleFavorite(_ progress: WordProgress) -> WordProgress {
        var next = progress
        next.isFavorite.toggle()
        return next
    }
}
