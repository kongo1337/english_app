import XCTest

@MainActor
final class TabsUITests: XCTestCase {
    private let titles = ["Учить", "Повторить", "Словари", "Прогресс", "Настройки"]

    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testFiveTabsAreVisible() {
        let app = XCUIApplication()
        app.launch()
        for title in titles {
            XCTAssertTrue(app.tabBars.buttons[title].waitForExistence(timeout: 5), "missing tab \(title)")
        }
    }

    func testTabsSwitchScreens() {
        let app = XCUIApplication()
        app.launch()
        let screens = ["learn", "review", "dictionaries", "progress", "settings"]
        for (title, screen) in zip(titles, screens) {
            app.tabBars.buttons[title].tap()
            XCTAssertTrue(app.otherElements["screen.\(screen)"].waitForExistence(timeout: 5), "no screen for \(title)")
        }
    }
}
