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
        // The first list cell is the filter bar, so look the word up by its identifier.
        let row = app.descendants(matching: .any)["wordRow.abandon_verb"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "search found nothing: \(app.debugDescription)")
        row.tap()

        let status = app.descendants(matching: .any)["detailStatus"]
        XCTAssertTrue(status.waitForExistence(timeout: 5), "no detail screen: \(app.debugDescription)")
        XCTAssertEqual(status.label, "Новое")
        app.buttons["markKnownButton"].tap()
        wait(for: { status.label == "Знаю" }, "status did not become 'Знаю'")

        app.buttons["returnToLearningButton"].tap()
        wait(for: { status.label == "Учу" }, "status did not become 'Учу'")
    }

    func testRaisingTheLevelChangesTheCardsInTheLearnTab() {
        // Start: the first cards are A1 words of the Oxford 3000.
        app.tabBars.buttons["Учить"].tap()
        XCTAssertTrue(app.staticTexts["Уровень A1"].waitForExistence(timeout: 10), "expected an A1 word first")

        app.tabBars.buttons["Словари"].tap()
        let b1 = app.buttons["levelChip.B1"]
        var swipes = 0
        while !b1.isHittable, swipes < 4 {
            app.swipeUp()
            swipes += 1
        }
        b1.tap()
        XCTAssertTrue(app.staticTexts["levelSummary"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Учить"].tap()
        XCTAssertTrue(app.staticTexts["Уровень B1"].waitForExistence(timeout: 10), "expected a B1 word now")
        XCTAssertFalse(app.staticTexts["Уровень A1"].exists, "no A1 word may remain")
        XCTAssertFalse(app.staticTexts["Уровень A2"].exists, "no A2 word may remain")
    }

    private func wait(for condition: @escaping () -> Bool, _ message: String, timeout: TimeInterval = 6,
                      file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: timeout), .completed, message, file: file, line: line)
    }
}
