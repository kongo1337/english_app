import XCTest

@MainActor
final class ReviewUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(seedReviews: Int) {
        app.launchArguments = ["-uiTesting", "-seedReviews", String(seedReviews)]
        app.launch()
        XCTAssertTrue(app.staticTexts["headerSubtitle"].waitForExistence(timeout: 15), "app did not start")
        app.tabBars.buttons.element(boundBy: 1).tap()
    }

    private var word: XCUIElement { app.staticTexts["cardWord"] }
    private var subtitle: XCUIElement { app.staticTexts["reviewSubtitle"] }

    private func wait(for condition: @escaping () -> Bool, _ message: String, timeout: TimeInterval = 6,
                      file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: timeout), .completed, message, file: file, line: line)
    }

    func testEmptyQueueShowsTheEmptyCard() {
        app.launchArguments = ["-uiTesting"]
        app.launch()
        XCTAssertTrue(app.staticTexts["headerSubtitle"].waitForExistence(timeout: 15))
        app.tabBars.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(app.otherElements["reviewEmpty"].waitForExistence(timeout: 5))
    }

    func testAnsweringEveryWordEmptiesTheQueue() {
        launch(seedReviews: 2)
        wait(for: { self.subtitle.exists && self.subtitle.label == "Осталось 2 слова" }, "wrong subtitle")
        let first = word.label
        app.buttons["rememberedButton"].tap()
        wait(for: { self.word.exists && self.word.label != first }, "card did not change")
        wait(for: { self.subtitle.label == "Осталось 1 слово" }, "count did not drop")
        XCTAssertTrue(app.buttons["undoButton"].isEnabled)

        app.buttons["forgotButton"].tap()
        XCTAssertTrue(app.otherElements["reviewEmpty"].waitForExistence(timeout: 5))
    }

    func testUndoBringsTheCardBack() {
        launch(seedReviews: 2)
        wait(for: { self.word.exists }, "no card")
        let first = word.label
        app.buttons["rememberedButton"].tap()
        wait(for: { self.word.exists && self.word.label != first }, "card did not change")
        app.buttons["undoButton"].tap()
        wait(for: { self.word.exists && self.word.label == first }, "undo did not restore the card")
    }

    func testSwipeRightCountsAsRemembered() {
        launch(seedReviews: 2)
        wait(for: { self.word.exists }, "no card")
        app.otherElements["card"].swipeRight()
        wait(for: { self.subtitle.label == "Осталось 1 слово" }, "swipe did not answer")
    }
}
