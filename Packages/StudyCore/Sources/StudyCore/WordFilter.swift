import Foundation

/// A chip in the word list: one status, or one of the two cross-cutting marks.
public enum StatusFilter: String, CaseIterable, Hashable, Sendable {
    case new, learning, review, mastered, known, hard, favorite

    func matches(_ progress: WordProgress?) -> Bool {
        let status = progress?.status ?? .new
        switch self {
        case .new: return status == .new
        case .learning: return status == .learning
        case .review: return status == .review
        case .mastered: return status == .mastered
        case .known: return status == .known
        case .hard: return progress?.isHard ?? false
        case .favorite: return progress?.isFavorite ?? false
        }
    }
}

public enum WordSort: String, CaseIterable, Sendable {
    /// The order of the Oxford lists (by level, then alphabetically).
    case dictionary
    case alphabetical
    /// Most recently seen first; words never seen go last in dictionary order.
    case recent
}

/// Which words the dictionary list shows. Empty sets mean "no restriction"; the chosen
/// statuses are alternatives (a word passes if it matches any of them).
public struct WordFilter: Equatable, Sendable {
    public var query = ""
    public var list: WordList?
    public var levels: Set<CEFRLevel> = []
    public var statuses: Set<StatusFilter> = []
    public var sort: WordSort = .dictionary

    public init(
        query: String = "", list: WordList? = nil, levels: Set<CEFRLevel> = [],
        statuses: Set<StatusFilter> = [], sort: WordSort = .dictionary
    ) {
        self.query = query
        self.list = list
        self.levels = levels
        self.statuses = statuses
        self.sort = sort
    }

    public var isActive: Bool { !levels.isEmpty || !statuses.isEmpty }

    /// With a search query the best matches come first, whatever `sort` says.
    public func apply(to catalog: WordCatalog, progress: [String: WordProgress]) -> [Word] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = trimmed.isEmpty ? catalog.words : catalog.search(trimmed, limit: catalog.count)
        let kept = source.filter { word in
            if let list, word.list != list { return false }
            if !levels.isEmpty, !levels.contains(word.cefr) { return false }
            if !statuses.isEmpty {
                let entry = progress[word.id]
                if !statuses.contains(where: { $0.matches(entry) }) { return false }
            }
            return true
        }
        guard trimmed.isEmpty else { return kept }
        switch sort {
        case .dictionary:
            return kept
        case .alphabetical:
            return kept.sorted { $0.lemma.lowercased() < $1.lemma.lowercased() }
        case .recent:
            let seen = kept.filter { progress[$0.id]?.lastSeenAt != nil }
                .sorted { (progress[$0.id]?.lastSeenAt ?? .distantPast) > (progress[$1.id]?.lastSeenAt ?? .distantPast) }
            let unseen = kept.filter { progress[$0.id]?.lastSeenAt == nil }
            return seen + unseen
        }
    }
}
