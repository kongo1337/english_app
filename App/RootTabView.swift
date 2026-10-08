import SwiftUI

struct RootTabView: View {
    let app: AppEnvironment
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection: AppTab = .learn

    var body: some View {
        TabView(selection: $selection) {
            LearnView(app: app, openReview: { selection = .review })
                .tabItem { Label(AppTab.learn.title, systemImage: AppTab.learn.symbol) }
                .tag(AppTab.learn)

            ReviewView(app: app)
                .tabItem { Label(AppTab.review.title, systemImage: AppTab.review.symbol) }
                .badge(app.study.reviewDueCount)
                .tag(AppTab.review)

            PlaceholderScreen(tab: .dictionaries)
                .tabItem { Label(AppTab.dictionaries.title, systemImage: AppTab.dictionaries.symbol) }
                .tag(AppTab.dictionaries)

            PlaceholderScreen(tab: .progress)
                .tabItem { Label(AppTab.progress.title, systemImage: AppTab.progress.symbol) }
                .tag(AppTab.progress)

            PlaceholderScreen(tab: .settings)
                .tabItem { Label(AppTab.settings.title, systemImage: AppTab.settings.symbol) }
                .tag(AppTab.settings)
        }
        .tint(Theme.accent)
        .onChange(of: scenePhase) { _, phase in
            // Coming back to the app may mean a new study day has started.
            if phase == .active { app.study.refreshDay() }
        }
        .task { app.study.startDayWatcher() }
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
