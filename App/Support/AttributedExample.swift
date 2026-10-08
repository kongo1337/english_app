import Foundation
import StudyCore

extension ExampleHighlighter {
    /// The example sentence with the studied word (and its regular forms) in bold.
    static func attributed(_ example: String, lemma: String) -> AttributedString {
        var result = AttributedString(example)
        if let range = range(of: lemma, in: example), let target = Range(range, in: result) {
            result[target].inlinePresentationIntent = .stronglyEmphasized
        }
        return result
    }
}
