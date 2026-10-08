import Foundation
import StudyCore

enum AppResources {
    static func dictionaryURL(in bundle: Bundle = .main) -> URL? {
        bundle.url(forResource: "words", withExtension: "json")
    }

    static func loadCatalog(in bundle: Bundle = .main) throws -> WordCatalog {
        guard let url = dictionaryURL(in: bundle) else { throw CocoaError(.fileNoSuchFile) }
        return try WordCatalog.load(contentsOf: url)
    }
}
