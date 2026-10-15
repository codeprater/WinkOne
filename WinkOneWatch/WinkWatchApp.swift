import SwiftUI

@main
struct WinkWatchApp: App {
    @StateObject private var store = WatchStore.shared

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(store)
                .tint(WatchColor.volt)
        }
    }
}
