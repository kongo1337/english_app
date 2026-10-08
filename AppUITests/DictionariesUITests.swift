import XCTest

@MainActor
final class DictionariesUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        XCTAssertTrue(app.staticTexts["headerSubtitle"].waitForExistence(timeout: 15), "app did not start")
        app.tabBars.buttons["Словари"].tap()
    }

    func testBothDictionariesAreListed() {
        XCTAssertTrue(app.staticTexts["screen.dictionaries"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["dictionaryCard.ox3000"].exists)
        XCTAssertTrue(app.buttons["dictionaryCard.ox5000"].exists)
    }

    func testSearchOpenAndMarkAWordAsKnown() {
        app.buttons["dictionaryCard.ox3000"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5), "no search field: \(app.debugDescription)")
        search.tap()
        search.typeText("abandon")
        let row = app.cells.firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "search found nothing")
        row.tap()

        let status = app.staticTexts["detailStatus"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertEqual(status.label, "Новое")
        app.buttons["markKnownButton"].tap()
        wait(for: { status.label == "Знаю" }, "status did not become 'Знаю'")

        app.buttons["returnToLearningButton"].tap()
        wait(for: { status.label == "Учу" }, "status did not become 'Учу'")
    }

    private func wait(for condition: @escaping () -> Bool, _ message: String, timeout: TimeInterval = 6,
                      file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: timeout), .completed, message, file: file, line: line)
    }
}
