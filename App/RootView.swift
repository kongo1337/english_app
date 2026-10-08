import SwiftUI

/// Shows a splash while the dictionary loads, then the tabs.
struct RootView: View {
    let model: AppModel

    var body: some View {
        Group {
            switch model.state {
            case .loading:
                SplashView()
            case .failed(let message):
                FailureView(message: message)
            case .ready(let environment):
                RootTabView(app: environment)
                    .environment(environment)
                    .environment(environment.study)
                    .environment(environment.settings)
                    .preferredColorScheme(environment.settings.values.theme.colorScheme)
            }
        }
        .task { await model.start() }
    }
}

private struct SplashView: View {
    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ProgressView()
        }
        .accessibilityIdentifier("splash")
    }
}

private struct FailureView: View {
    let message: String

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: Theme.Spacing.medium) {
                Text("Не удалось запустить приложение")
                    .font(Theme.Typography.cardTitle)
                    .foregroundStyle(Theme.textPrimary)
                Text(message)
                    .font(Theme.Typography.small)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(Theme.Spacing.screen)
        }
        .accessibilityIdentifier("failure")
    }
}
