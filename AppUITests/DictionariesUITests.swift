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

    func testChoosingLevelsChangesTheCardsInTheLearnTab() {
        // Start: every level is on, the first cards are A1 words.
        app.tabBars.buttons["Учить"].tap()
        XCTAssertTrue(app.staticTexts["Уровень A1"].waitForExistence(timeout: 10), "expected an A1 word first")

        // Leave only B1, B2 and C1.
        app.tabBars.buttons["Словари"].tap()
        let a1 = app.buttons["levelChip.A1"]
        var swipes = 0
        while !a1.isHittable, swipes < 4 {
            app.swipeUp()
            swipes += 1
        }
        a1.tap()
        app.buttons["levelChip.A2"].tap()
        XCTAssertTrue(app.staticTexts["levelSummary"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["levelSummary"].label.contains("вперемешку"), "the summary says the levels are mixed")

        app.tabBars.buttons["Учить"].tap()
        let chosen = ["Уровень B1", "Уровень B2", "Уровень C1"].map { app.staticTexts[$0] }
        wait(for: { chosen.contains { $0.exists } }, "expected a card of a chosen level", timeout: 10)
        XCTAssertFalse(app.staticTexts["Уровень A1"].exists, "no A1 word may remain")
        XCTAssertFalse(app.staticTexts["Уровень A2"].exists, "no A2 word may remain")

        // Swap to A2 + A1 only: the cards change again.
        app.tabBars.buttons["Словари"].tap()
        app.buttons["levelAll"].tap()
        for level in ["B1", "B2", "C1"] { app.buttons["levelChip.\(level)"].tap() }
        app.tabBars.buttons["Учить"].tap()
        let easy = ["Уровень A1", "Уровень A2"].map { app.staticTexts[$0] }
        wait(for: { easy.contains { $0.exists } }, "expected an A1/A2 card after switching", timeout: 10)
        XCTAssertFalse(app.staticTexts["Уровень B1"].exists)
    }

    private func wait(for condition: @escaping () -> Bool, _ message: String, timeout: TimeInterval = 6,
                      file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: timeout), .completed, message, file: file, line: line)
    }
}
