import StudyCore
import Testing
import UIKit

@testable import EnglishCards

@Suite struct SmokeTests {
    @Test func bundledDictionaryLoads() throws {
        let catalog = try AppResources.loadCatalog()
        #expect(catalog.count == 5938)
        #expect(catalog.count(in: .ox3000) == 3809)
        #expect(catalog.count(in: .ox5000) == 2129)
    }

    @Test(arguments: ThemeToken.allCases)
    func everyColourTokenExistsInBothAppearances(token: ThemeToken) throws {
        let color = try #require(token.uiColor, "missing colour set \(token.rawValue)")
        let light = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        let dark = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        #expect(light != dark, "\(token.rawValue) has no dark variant")
    }

    @Test func tabsAreInTheDocumentedOrder() {
        #expect(AppTab.allCases.map(\.rawValue) == ["learn", "review", "dictionaries", "progress", "settings"])
        #expect(AppTab.allCases.map(\.symbol) == [
            "book", "arrow.triangle.2.circlepath", "square.grid.2x2", "chart.bar", "gearshape",
        ])
    }
}
