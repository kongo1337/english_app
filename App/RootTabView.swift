import SwiftUI

struct RootTabView: View {
    @State private var selection: AppTab = .learn

    var body: some View {
        TabView(selection: $selection) {
            ForEach(AppTab.allCases) { tab in
                PlaceholderScreen(tab: tab)
                    .tabItem { Label(tab.title, systemImage: tab.symbol) }
                    .tag(tab)
            }
        }
        .tint(Theme.accent)
    }
}

/// Stands in for a tab until its real screen is built.
struct PlaceholderScreen: View {
    let tab: AppTab

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 4) {
                Text(tab.title)
                    .font(Theme.Typography.screenTitle)
                    .foregroundStyle(Theme.textPrimary)
                Text("Этот экран появится на следующем этапе")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.screen)
            .padding(.top, Theme.Spacing.large)
        }
        .accessibilityIdentifier("screen.\(tab.rawValue)")
    }
}

#Preview("Light") {
    RootTabView()
}

#Preview("Dark") {
    RootTabView().preferredColorScheme(.dark)
}
