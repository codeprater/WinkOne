import SwiftUI

@main
struct WinkApp: App {
    init() {
        WinkNotify.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
