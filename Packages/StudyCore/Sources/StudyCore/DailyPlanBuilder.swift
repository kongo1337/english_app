import Foundation

/// Builds the daily plan: carry-over ("still learning") words first, then new ones.
public enum DailyPlanBuilder {
    /// New words that may be studied now, in study order.
    ///
    /// A word is "new" when it has no progress row or its status is `.new`, it belongs to an
    /// enabled list, and it is not in `excluding`.
    public static func orderedNewWords(
        catalog: WordCatalog, progress: [String: WordProgress], settings: StudySettings,
        excluding: Set<String> = []
    ) -> [Word] {
        let candidates = catalog.words.filter { word in
            settings.enabledLists.contains(word.list)
                && !excluding.contains(word.id)
                && (progress[word.id]?.status ?? .new) == .new
        }
        switch settings.order {
        case .byLevel:
            return candidates.sorted { lhs, rhs in
                if lhs.list != rhs.list { return lhs.list < rhs.list }
                if lhs.cefr != rhs.cefr { return lhs.cefr < rhs.cefr }
                let l = SeededRandom.stableValue(seed: settings.seed, key: lhs.id)
                let r = SeededRandom.stableValue(seed: settings.seed, key: rhs.id)
                return l != r ? l < r : lhs.id < rhs.id
            }
        case .random:
            return candidates.sorted { lhs, rhs in
                let l = SeededRandom.stableValue(seed: settings.seed, key: lhs.id)
                let r = SeededRandom.stableValue(seed: settings.seed, key: rhs.id)
                return l != r ? l < r : lhs.id < rhs.id
            }
        case .alphabetical:
            return candidates.sorted { lhs, rhs in
                let l = lhs.lemma.lowercased(), r = rhs.lemma.lowercased()
                return l != r ? l < r : lhs.id < rhs.id
            }
        }
    }

    /// "Still learning" words from previous days, the longest-waiting first.
    public static func carryover(catalog: WordCatalog, progress: [String: WordProgress]) -> [String] {
        progress.values
            .filter { $0.status == .learning && catalog.contains($0.wordId) }
            .sorted { lhs, rhs in
                switch (lhs.lastSeenAt, rhs.lastSeenAt) {
                case let (l?, r?) where l != r: return l < r
                case (nil, .some): return true
                case (.some, nil): return false
                default: return lhs.wordId < rhs.wordId
                }
            }
            .map(\.wordId)
    }

    /// How many new words go into the plan: `min(N, max(0, N + B - carryover))`.
    public static func newWordCount(carryover: Int, settings: StudySettings) -> Int {
        let n = max(0, settings.newWordsPerDay)
        let b = max(0, settings.carryoverBuffer)
        return min(n, max(0, n + b - carryover))
    }

    public static func build(
        dayKey: DayKey, catalog: WordCatalog, progress: [String: WordProgress],
        settings: StudySettings, reviewTarget: Int = 0
    ) -> DailyPlan {
        let carried = carryover(catalog: catalog, progress: progress)
        let count = newWordCount(carryover: carried.count, settings: settings)
        let fresh = orderedNewWords(catalog: catalog, progress: progress, settings: settings)
            .prefix(count)
            .map(\.id)
        return DailyPlan(dayKey: dayKey, wordIds: carried + fresh, reviewTarget: reviewTarget)
    }

    /// The next batch for the "N more words" button.
    public static func extraWords(
        plan: DailyPlan, catalog: WordCatalog, progress: [String: WordProgress],
        settings: StudySettings
    ) -> [String] {
        orderedNewWords(
            catalog: catalog, progress: progress, settings: settings,
            excluding: Set(plan.wordIds)
        )
        .prefix(max(0, settings.extraBatchSize))
        .map(\.id)
    }
}
