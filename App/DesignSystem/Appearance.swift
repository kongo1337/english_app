import UIKit

/// UIKit appearance for the pieces SwiftUI cannot style yet (tab bar background and badge).
@MainActor
enum Appearance {
    static func configure() {
        let background = ThemeToken.bg.uiColor
        let badge = ThemeToken.badge.uiColor

        let item = UITabBarItemAppearance()
        item.normal.badgeBackgroundColor = badge
        item.selected.badgeBackgroundColor = badge

        let tabBar = UITabBarAppearance()
        tabBar.configureWithOpaqueBackground()
        tabBar.backgroundColor = background
        tabBar.shadowColor = ThemeToken.border.uiColor
        tabBar.stackedLayoutAppearance = item
        tabBar.inlineLayoutAppearance = item
        tabBar.compactInlineLayoutAppearance = item

        UITabBar.appearance().standardAppearance = tabBar
        UITabBar.appearance().scrollEdgeAppearance = tabBar
    }
}
