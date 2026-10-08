import Foundation

/// Launch arguments that switch the app into a deterministic mode for UI tests and previews.
///
/// - `-uiTesting`: in-memory storage and fresh settings, nothing is read from or written to disk.
/// - `-fixedNow 2026-10-08T12:00:00Z`: the app believes it is this instant.
/// - `-newWordsPerDay 3`: a tiny daily plan, so a whole study day fits into one UI test.
/// - `-seedReviews 2`: that many words are already learned and due for repetition today.
struct LaunchOptions: Equatable {
    var uiTesting = false
    var fixedNow: Date?
    var newWordsPerDay: Int?
    var seedReviews: Int?

    static var current: LaunchOptions { parse(ProcessInfo.processInfo.arguments) }

    static func parse(_ arguments: [String]) -> LaunchOptions {
        var options = LaunchOptions()
        options.uiTesting = arguments.contains("-uiTesting")
        if let index = arguments.firstIndex(of: "-fixedNow"), arguments.indices.contains(index + 1) {
            options.fixedNow = ISO8601DateFormatter().date(from: arguments[index + 1])
        }
        if let index = arguments.firstIndex(of: "-newWordsPerDay"), arguments.indices.contains(index + 1) {
            options.newWordsPerDay = Int(arguments[index + 1])
        }
        if let index = arguments.firstIndex(of: "-seedReviews"), arguments.indices.contains(index + 1) {
            options.seedReviews = Int(arguments[index + 1])
        }
        return options
    }
}
