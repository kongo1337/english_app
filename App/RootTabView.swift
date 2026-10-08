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

            DictionariesView(app: app)
                .tabItem { Label(AppTab.dictionaries.title, systemImage: AppTab.dictionaries.symbol) }
                .tag(AppTab.dictionaries)

            ProgressScreen(app: app)
                .tabItem { Label(AppTab.progress.title, systemImage: AppTab.progress.symbol) }
                .tag(AppTab.progress)

            SettingsScreen(app: app)
                .tabItem { Label(AppTab.settings.title, systemImage: AppTab.settings.symbol) }
                .tag(AppTab.settings)
        }
        .tint(Theme.accent)
        .onChange(of: scenePhase) { _, phase in
            // Coming back to the app may mean a new study day has started.
            if phase == .active { app.study.refreshDay() }
        }
        .task { app.study.startDayWatcher() }
        .onChange(of: app.study.phase) { _, phase in
            // The first finished set of cards is the moment to ask for notification permission.
            if case .card = phase { return }
            app.reminders.noteSessionFinished()
        }
        .task(id: app.reminders.signature) { await app.reminders.refresh() }
    }
}

#Preview("Light") {
    RootView(model: AppModel(options: LaunchOptions(uiTesting: true)))
}

#Preview("Dark") {
    RootView(model: AppModel(options: LaunchOptions(uiTesting: true))).preferredColorScheme(.dark)
}
