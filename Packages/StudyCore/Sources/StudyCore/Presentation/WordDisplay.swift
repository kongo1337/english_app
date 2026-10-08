import Foundation

extension PartOfSpeech {
    /// Short Russian label for the card header.
    public var shortRussianName: String {
        switch self {
        case .noun: "сущ."
        case .verb: "гл."
        case .adjective: "прил."
        case .adverb: "нареч."
        case .preposition: "предлог"
        case .conjunction: "союз"
        case .pronoun: "мест."
        case .determiner: "опред."
        case .number: "числ."
        case .exclamation: "межд."
        case .modal: "мод. гл."
        case .auxiliary: "вспом. гл."
        case .article: "артикль"
        case .other: ""
        }
    }
}

extension Word {
    /// "сущ. · money": part of speech plus the Oxford sense note, when there is one.
    public var headerDetail: String {
        [pos.shortRussianName, sense].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

/// Finds the studied word inside its example sentence, including inflected forms
/// ("abandon" → "abandoned"), so it can be shown in bold.
public enum ExampleHighlighter {
    public static func range(of lemma: String, in text: String) -> Range<String.Index>? {
        let words = lemma.split(whereSeparator: { !$0.isLetter }).map(String.init)
        guard let first = words.first(where: { $0.count >= 2 }) ?? words.first else { return nil }
        // Short words must match whole; longer ones allow endings (-s, -ed, -ing, -ly…).
        let stem = first.count <= 3 ? first : String(first.prefix(max(3, first.count - 2)))

        var searchStart = text.startIndex
        while let found = text.range(
            of: stem, options: [.caseInsensitive, .diacriticInsensitive], range: searchStart..<text.endIndex)
        {
            let startsWord = found.lowerBound == text.startIndex || !text[text.index(before: found.lowerBound)].isLetter
            if startsWord {
                var end = found.upperBound
                while end < text.endIndex, text[end].isLetter { end = text.index(after: end) }
                if first.count > 3 || end == found.upperBound { return found.lowerBound..<end }
                // A short word must stand alone: "go" is not "going".
            }
            searchStart = found.upperBound
        }
        return nil
    }
}
