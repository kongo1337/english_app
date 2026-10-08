import SwiftUI

@main
struct EnglishCardsApp: App {
    init() {
        Appearance.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
    }
}
