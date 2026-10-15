#if os(watchOS)
// Main entry point for the watchOS version of Wink One.
// This starter implementation provides:
//  - Onboarding with policy summary (18+, zero-tolerance, reporting, etc.)
//  - A feed of received winks (read-only, local)
//  - Ability to report/block content
//  - Contact info

import SwiftUI

@main
struct WinkOneWatchApp: App {
    @AppStorage("winkWatchOnboarded") private var onboarded = false

    var body: some Scene {
        WindowGroup {
            if onboarded {
                WatchContentView()
            } else {
                WatchOnboardingView(onFinish: { onboarded = true })
            }
        }
    }
}
#endif
