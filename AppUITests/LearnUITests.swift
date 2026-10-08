import XCTest

@MainActor
final class LearnUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(plan: Int? = nil) {
        app.launchArguments = ["-uiTesting"] + (plan.map { ["-newWordsPerDay", String($0)] } ?? [])
        app.launch()
        XCTAssertTrue(word.waitForExistence(timeout: 15), "no card on screen")
    }

    private var word: XCUIElement { app.staticTexts["cardWord"] }
    private var subtitle: XCUIElement { app.staticTexts["headerSubtitle"] }

    private func wait(for condition: @escaping () -> Bool, _ message: String, timeout: TimeInterval = 6,
                      file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: timeout), .completed, message, file: file, line: line)
    }

    private func waitForSubtitle(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        wait(for: { self.subtitle.exists && self.subtitle.label == text }, "subtitle never became '\(text)'", file: file, line: line)
    }

    /// Taps a button and waits until the next card has appeared (taps during the fly-out are ignored).
    private func tapAndWaitForNextCard(_ button: String, file: StaticString = #filePath, line: UInt = #line) {
        let before = word.label
        app.buttons[button].tap()
        wait(for: { self.word.exists && self.word.label != before }, "card did not change after \(button)", file: file, line: line)
    }

    private func hasCyrillic(_ text: String) -> Bool {
        text.range(of: "[А-Яа-я]", options: .regularExpression) != nil
    }

    func testHeaderShowsTheDailyPlan() {
        launch()
        waitForSubtitle("Выучено 0 из 60 за сегодня")
        XCTAssertFalse(app.buttons["undoButton"].isEnabled)
    }

    func testStillLearningCardReturnsAfterSevenCards() {
        launch()
        let first = word.label
        tapAndWaitForNextCard("stillLearningButton")
        for _ in 0..<7 { tapAndWaitForNextCard("learnedButton") }
        XCTAssertEqual(word.label, first, "the card marked 'still learning' should come back")
        waitForSubtitle("Выучено 7 из 60 за сегодня")
    }

    func testFlipShowsTheTranslationAndBack() {
        launch()
        let english = word.label
        app.buttons["flipButton"].tap()
        XCTAssertTrue(app.staticTexts["cardAnswer"].waitForExistence(timeout: 5))
        XCTAssertNotEqual(app.staticTexts["cardAnswer"].label, english)
        // Tap the empty left margin of the card, away from every control.
        app.otherElements["card"].coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.5)).tap()
        wait(for: { self.word.exists && self.word.label == english }, "card did not flip back")
    }

    func testUndoBringsTheCardBack() {
        launch()
        let first = word.label
        tapAndWaitForNextCard("learnedButton")
        waitForSubtitle("Выучено 1 из 60 за сегодня")
        app.buttons["undoButton"].tap()
        waitForSubtitle("Выучено 0 из 60 за сегодня")
        wait(for: { self.word.exists && self.word.label == first }, "undo did not bring the first card back")
    }

    func testDirectionSwitchShowsRussianFirst() {
        launch()
        XCTAssertFalse(hasCyrillic(word.label))
        app.buttons["directionButton"].tap()
        wait(for: { self.word.exists && self.hasCyrillic(self.word.label) }, "front side did not switch to Russian")
    }

    func testSwipeRightMarksTheWordLearned() {
        launch()
        let first = word.label
        app.otherElements["card"].swipeRight()
        wait(for: { self.word.exists && self.word.label != first }, "swipe did not move to the next card")
        waitForSubtitle("Выучено 1 из 60 за сегодня")
    }

    func testHelpSheetOpensAndCloses() {
        launch()
        app.buttons["helpButton"].tap()
        XCTAssertTrue(app.buttons["helpDone"].waitForExistence(timeout: 5))
        app.buttons["helpDone"].tap()
        XCTAssertTrue(word.waitForExistence(timeout: 5))
    }

    func testFinishingThePlanShowsTheDayCompleteCard() {
        launch(plan: 3)
        waitForSubtitle("Выучено 0 из 3 за сегодня")
        tapAndWaitForNextCard("learnedButton")
        tapAndWaitForNextCard("learnedButton")
        app.buttons["learnedButton"].tap()
        XCTAssertTrue(app.otherElements["dayComplete"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["countdown"].exists)
        waitForSubtitle("Выучено 3 из 3 за сегодня")

        app.buttons["moreWordsButton"].tap()
        XCTAssertTrue(word.waitForExistence(timeout: 5))
        waitForSubtitle("Выучено 3 из 13 за сегодня")
    }

    func testRoundCompleteOffersToGoThroughHardWordsAgain() {
        launch(plan: 2)
        tapAndWaitForNextCard("stillLearningButton")
        app.buttons["stillLearningButton"].tap()
        XCTAssertTrue(app.otherElements["roundComplete"].waitForExistence(timeout: 5))

        app.buttons["continueRoundButton"].tap()
        XCTAssertTrue(word.waitForExistence(timeout: 5))
        tapAndWaitForNextCard("stillLearningButton")
        app.buttons["stillLearningButton"].tap()
        XCTAssertTrue(app.buttons["finishDayButton"].waitForExistence(timeout: 5))
        app.buttons["finishDayButton"].tap()
        XCTAssertTrue(app.otherElements["dayComplete"].waitForExistence(timeout: 5))
    }
}
