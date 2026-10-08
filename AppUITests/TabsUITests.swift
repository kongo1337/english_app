import XCTest

@MainActor
final class TabsUITests: XCTestCase {
    private let titles = ["Учить", "Повторить", "Словари", "Прогресс", "Настройки"]

    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testFiveTabsAreVisible() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        for title in titles {
            XCTAssertTrue(app.tabBars.buttons[title].waitForExistence(timeout: 10), "missing tab \(title)")
        }
    }

    func testTabsSwitchScreens() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        // The Learn tab shows its header; the other tabs still show a placeholder title.
        XCTAssertTrue(app.staticTexts["headerSubtitle"].waitForExistence(timeout: 10), "no Learn screen")
        for (title, screen) in zip(titles.dropFirst(), ["review", "dictionaries", "progress", "settings"]) {
            app.tabBars.buttons[title].tap()
            XCTAssertTrue(app.staticTexts["screen.\(screen)"].waitForExistence(timeout: 5), "no screen for \(title)")
        }
    }
}
