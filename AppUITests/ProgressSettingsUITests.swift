import XCTest

@MainActor
final class ProgressSettingsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        XCTAssertTrue(app.staticTexts["headerSubtitle"].waitForExistence(timeout: 15), "app did not start")
    }

    func testProgressShowsTheStreakAndTotals() {
        app.tabBars.buttons["Прогресс"].tap()
        XCTAssertTrue(app.staticTexts["screen.progress"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["streakText"].label, "Серии пока нет")
        XCTAssertTrue(app.staticTexts["Итоги"].exists)
    }

    func testSettingsListsTheSections() {
        app.tabBars.buttons["Настройки"].tap()
        XCTAssertTrue(app.staticTexts["screen.settings"].waitForExistence(timeout: 5))
        // The list builds rows lazily, so scroll down to the data section first.
        let export = app.buttons["exportButton"]
        var swipes = 0
        while !export.exists, swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(export.exists, "no export button: \(app.debugDescription)")
        XCTAssertTrue(app.buttons["importButton"].exists)
    }

    func testResetNeedsTwoConfirmations() {
        app.tabBars.buttons["Настройки"].tap()
        let reset = app.buttons["resetAllButton"]
        var swipes = 0
        while !reset.isHittable, swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        reset.tap()
        let first = app.buttons["Сбросить…"]
        XCTAssertTrue(first.waitForExistence(timeout: 5), "no first confirmation")
        first.tap()
        let second = app.buttons["Удалить навсегда"]
        XCTAssertTrue(second.waitForExistence(timeout: 5), "no second confirmation")
        second.tap()
        XCTAssertTrue(app.staticTexts["Весь прогресс удалён."].waitForExistence(timeout: 5))
    }
}
