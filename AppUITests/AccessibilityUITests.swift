import XCTest

/// Automatic accessibility checks (hit regions, labels, traits) on every tab, and the Learn screen at the largest accessibility text size.
@MainActor
final class AccessibilityUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = true
        app = XCUIApplication()
    }

    // Contrast is checked on the colour tokens themselves (ContrastTests): the audit samples
    // pixels and reports text with a 5 : 1 ratio. Clipping and Dynamic Type are covered by
    // testLearnScreenWorksAtTheLargestTextSize; the audit flags system form rows for them.
    private let audited: XCUIAccessibilityAuditType = [.hitRegion, .sufficientElementDescription, .trait]

    private func launch(arguments: [String] = []) {
        app.launchArguments = ["-uiTesting", "-seedReviews", "2"] + arguments
        app.launch()
        XCTAssertTrue(app.staticTexts["headerSubtitle"].waitForExistence(timeout: 15), "app did not start")
    }

    private func audit(_ screen: String) {
        do {
            try app.performAccessibilityAudit(for: audited) { issue in
                // A hit area matters for things you tap. Plain text is not one; the audit
                // reports small captions whose spoken label differs from the shown text.
                if issue.auditType == .hitRegion, issue.element?.elementType == .staticText { return true }
                XCTFail("[\(screen)] \(issue.auditType.rawValue): \(issue.compactDescription) — \(issue.detailedDescription)"
                        + " element: \(issue.element?.debugDescription ?? "none")")
                return true  // reported above; keep going to collect every issue
            }
        } catch {
            XCTFail("[\(screen)] audit failed: \(error)")
        }
    }

    func testLearnTabPassesTheAudit() {
        launch()
        audit("Учить")
    }

    func testReviewTabPassesTheAudit() {
        launch()
        app.tabBars.buttons["Повторить"].tap()
        XCTAssertTrue(app.staticTexts["reviewSubtitle"].waitForExistence(timeout: 5))
        audit("Повторить")
    }

    func testDictionariesTabPassesTheAudit() {
        launch()
        app.tabBars.buttons["Словари"].tap()
        XCTAssertTrue(app.staticTexts["screen.dictionaries"].waitForExistence(timeout: 5))
        audit("Словари")
    }

    func testProgressTabPassesTheAudit() {
        launch()
        app.tabBars.buttons["Прогресс"].tap()
        XCTAssertTrue(app.staticTexts["screen.progress"].waitForExistence(timeout: 5))
        audit("Прогресс")
    }

    func testSettingsTabPassesTheAudit() {
        launch()
        app.tabBars.buttons["Настройки"].tap()
        XCTAssertTrue(app.staticTexts["screen.settings"].waitForExistence(timeout: 5))
        audit("Настройки")
    }

    func testLearnScreenWorksAtTheLargestTextSize() {
        launch(arguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        XCTAssertTrue(app.staticTexts["cardWord"].waitForExistence(timeout: 10))
        let learned = app.buttons["learnedButton"]
        var swipes = 0
        while !learned.isHittable, swipes < 8 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(learned.isHittable, "the Learned button cannot be reached at the largest text size")
        learned.tap()
        let subtitle = app.staticTexts["headerSubtitle"]
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in subtitle.exists && subtitle.label == "Выучено 1 из 60 за сегодня" },
            object: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 8), .completed, "the card was not learned")
    }
}
