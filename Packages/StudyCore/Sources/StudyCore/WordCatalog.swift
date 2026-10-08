import Foundation

public enum WordCatalogError: Error, Equatable {
    case duplicateId(String)
    case unsupportedFormat
}

/// The immutable dictionary loaded from `words.json`, with indexes and search.
public struct WordCatalog: Sendable {
    public let version: Int
    public let words: [Word]

    private let indexById: [String: Int]
    private let searchKeys: [SearchKey]

    private struct SearchKey: Sendable {
        let lemma: String
        let translations: [String]
    }

    private struct File: Decodable {
        let version: Int
        let words: [Word]
    }

    public init(words: [Word], version: Int = 0) throws {
        var index: [String: Int] = [:]
        index.reserveCapacity(words.count)
        for (position, word) in words.enumerated() {
            if index.updateValue(position, forKey: word.id) != nil {
                throw WordCatalogError.duplicateId(word.id)
            }
        }
        self.version = version
        self.words = words
        self.indexById = index
        self.searchKeys = words.map {
            SearchKey(
                lemma: WordCatalog.normalize($0.lemma),
                translations: $0.translations.map(WordCatalog.normalize))
        }
    }

    public static func load(data: Data) throws -> WordCatalog {
        let file = try JSONDecoder().decode(File.self, from: data)
        return try WordCatalog(words: file.words, version: file.version)
    }

    public static func load(contentsOf url: URL) throws -> WordCatalog {
        try load(data: Data(contentsOf: url))
    }

    // MARK: Lookup

    public var count: Int { words.count }

    public func word(id: String) -> Word? {
        indexById[id].map { words[$0] }
    }

    public func contains(_ id: String) -> Bool { indexById[id] != nil }

    public func words(in list: WordList) -> [Word] { words.filter { $0.list == list } }

    public func words(at level: CEFRLevel) -> [Word] { words.filter { $0.cefr == level } }

    public func count(in list: WordList) -> Int { words.lazy.filter { $0.list == list }.count }

    // MARK: Search

    /// Finds words by English lemma (exact, prefix, substring) or by Russian translation.
    /// Case-insensitive; "ё" and "е" are treated alike. Best matches come first.
    public func search(_ query: String, limit: Int = 200) -> [Word] {
        let needle = WordCatalog.normalize(query)
        guard !needle.isEmpty else { return [] }

        var matches: [(score: Int, position: Int)] = []
        for (position, key) in searchKeys.enumerated() {
            if let score = WordCatalog.score(key, needle) {
                matches.append((score, position))
            }
        }
        // Positions follow dictionary order, which keeps ties stable.
        matches.sort { ($0.score, $0.position) < ($1.score, $1.position) }
        return matches.prefix(limit).map { words[$0.position] }
    }

    private static func score(_ key: SearchKey, _ needle: String) -> Int? {
        if key.lemma == needle { return 0 }
        if key.lemma.hasPrefix(needle) { return 1 }
        if key.lemma.contains(needle) { return 2 }
        if key.translations.contains(where: { $0.hasPrefix(needle) }) { return 3 }
        if key.translations.contains(where: { $0.contains(needle) }) { return 4 }
        return nil
    }

    static func normalize(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "ё", with: "е")
    }
}
