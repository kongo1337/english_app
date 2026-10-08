import SwiftUI

struct RootTabView: View {
    @Environment(StudyService.self) private var study
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection: AppTab = .learn

    var body: some View {
        TabView(selection: $selection) {
            ForEach(AppTab.allCases) { tab in
                PlaceholderScreen(tab: tab)
                    .tabItem { Label(tab.title, systemImage: tab.symbol) }
                    .badge(tab == .review ? study.reviewDueCount : 0)
                    .tag(tab)
            }
        }
        .tint(Theme.accent)
        .onChange(of: scenePhase) { _, phase in
            // Coming back to the app may mean a new study day has started.
            if phase == .active { study.refreshDay() }
        }
        .task { study.startDayWatcher() }
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
                    .accessibilityIdentifier("screen.\(tab.rawValue)")
                Text("Этот экран появится на следующем этапе")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.screen)
            .padding(.top, Theme.Spacing.large)
        }
    }
}

#Preview("Light") {
    RootView(model: AppModel(options: LaunchOptions(uiTesting: true)))
}

#Preview("Dark") {
    RootView(model: AppModel(options: LaunchOptions(uiTesting: true))).preferredColorScheme(.dark)
}
