import SwiftUI

@main
struct EnglishCardsApp: App {
    @State private var model = AppModel()

    init() {
        Appearance.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
    }
}
