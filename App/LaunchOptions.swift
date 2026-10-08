import Foundation

/// Launch arguments that switch the app into a deterministic mode for UI tests and previews.
///
/// - `-uiTesting`: in-memory storage and fresh settings, nothing is read from or written to disk.
/// - `-fixedNow 2026-10-08T12:00:00Z`: the app believes it is this instant.
struct LaunchOptions: Equatable {
    var uiTesting = false
    var fixedNow: Date?

    static var current: LaunchOptions { parse(ProcessInfo.processInfo.arguments) }

    static func parse(_ arguments: [String]) -> LaunchOptions {
        var options = LaunchOptions()
        options.uiTesting = arguments.contains("-uiTesting")
        if let index = arguments.firstIndex(of: "-fixedNow"), arguments.indices.contains(index + 1) {
            options.fixedNow = ISO8601DateFormatter().date(from: arguments[index + 1])
        }
        return options
    }
}
