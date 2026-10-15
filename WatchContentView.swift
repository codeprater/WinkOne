// SwiftUI main content for Wink One watchOS
// Shows a feed of received winks, a way to view/report, and a settings/policy screen.

import SwiftUI

struct WatchContentView: View {
    @State private var showSettings = false
    @ObservedObject private var moderation = ModerationStore.shared
    @State private var selectedWink: ReceivedWink?

    var body: some View {
        NavigationStack {
            List {
                if moderation.received.isEmpty {
                    Text("No winks yet. Sent cards appear here.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(moderation.received) { wink in
                        Button(action: { selectedWink = wink }) {
                            VStack(alignment: .leading) {
                                Text(wink.fromName)
                                    .font(.headline)
                                Text(wink.payload.text.isEmpty ? (wink.payload.symbolName ?? "Card") : wink.payload.text)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Winks")
            .toolbar {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gear")
                }
            }
            .sheet(item: $selectedWink) { wink in
                WatchWinkDetailView(wink: wink)
            }
            .sheet(isPresented: $showSettings) {
                WatchSettingsView()
            }
        }
    }
}

struct WatchWinkDetailView: View {
    let wink: ReceivedWink
    @Environment(\.dismiss) private var dismiss
    @State private var showReport = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(wink.fromName)
                    .font(.title2)
                Text(wink.payload.text.isEmpty ? (wink.payload.symbolName ?? "Card") : wink.payload.text)
                    .font(.body)
                Button("Report & Block") { showReport = true }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .padding(.top, 8)
                Button("Dismiss") { dismiss() }
                    .padding(.top, 2)
            }
            .padding()
        }
        .sheet(isPresented: $showReport) {
            WatchReportView(wink: wink, onDone: { showReport = false; dismiss() })
        }
    }
}

struct WatchReportView: View {
    let wink: ReceivedWink
    var onDone: () -> Void
    @ObservedObject private var moderation = ModerationStore.shared

    var body: some View {
        VStack {
            Text("Report this card?")
                .font(.headline)
            Text("Sender: \(wink.fromName)")
                .font(.caption)
            Button("Report & Block") {
                _ = moderation.report(name: wink.fromName, reason: .other, details: "Reported from watch", evidence: wink.payload.text)
                moderation.remove(wink)
                onDone()
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            Button("Cancel", role: .cancel) { onDone() }
        }
        .padding()
    }
}

struct WatchSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.largeTitle)
                Text("WINK is for age 18+ only. Zero tolerance for objectionable content or abusive users. Every card is filtered.")
                    .font(.callout)
                Text("You can report or block any sender. Reports are reviewed within 24 hours. Contact: prater10@icloud.com")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}

// Onboarding for watchOS
struct WatchOnboardingView: View {
    var onFinish: () -> Void
    @State private var page = 0
    private let lastPage = 1

    var body: some View {
        VStack {
            TabView(selection: $page) {
                VStack(spacing: 12) {
                    Image(systemName: "eye")
                        .font(.largeTitle)
                    Text("WINK on your wrist!").font(.headline)
                    Text("View and manage received winks.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }.tag(0)
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.largeTitle)
                    Text("Age 18+ required. Zero tolerance for objectionable content and abusive users.")
                        .font(.callout)
                    Text("Every card is filtered before display. You can block or report any sender.")
                        .font(.footnote)
                    Text("Contact: prater10@icloud.com (Reports reviewed within 24 hours)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }.tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            Button(page == lastPage ? "Get Started" : "Next") {
                if page == lastPage {
                    onFinish()
                } else {
                    withAnimation { page += 1 }
                }
            }
            .padding(.top, 12)
        }
        .padding()
    }
}
