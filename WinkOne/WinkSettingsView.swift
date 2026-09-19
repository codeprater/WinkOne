import SwiftUI

/// The one place the preferences live, so nothing has to be discovered by
/// long-pressing something and hoping.
struct WinkSettingsView: View {
    var onClose: () -> Void

    @AppStorage("wink.walletScroll") private var walletScroll = false
    @AppStorage("wink.dockAutoHide") private var dockAutoHide = true
    @AppStorage("wink.radarSweep") private var radarSweep = true
    @AppStorage("winkName") private var winkName = ""

    @ObservedObject private var moderation = ModerationStore.shared
    @State private var showSafety = false
    @State private var showTerms = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $walletScroll) {
                        Label("Wallet Stack", systemImage: "rectangle.stack")
                    }
                    Text("Cards stack from the bottom up and scroll as one, the way passes do in Wallet. Off gives you the grid.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Cards")
                }

                Section {
                    Toggle(isOn: $dockAutoHide) {
                        Label("Hide Tools When Idle", systemImage: "chevron.down.square")
                    }
                    Text("The dock steps out of the way after a few quiet seconds and comes back on a tap or a swipe up.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    Toggle(isOn: $radarSweep) {
                        Label("Radar Sweep", systemImage: "dot.radiowaves.left.and.right")
                    }
                    Text("The rotating sweep on the wallpaper. Turning it off saves a little battery.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Screen")
                }

                Section {
                    Button {
                        showSafety = true
                    } label: {
                        Label("Safety Center", systemImage: "shield.lefthalf.filled")
                    }
                    Button {
                        showTerms = true
                    } label: {
                        Label("Terms & House Rules", systemImage: "doc.text")
                    }
                    LabeledContent("Blocked", value: "\(moderation.blocked.count)")
                    LabeledContent("Reports filed", value: "\(moderation.reports.count)")
                    LabeledContent("Filtered", value: "\(moderation.filteredCount)")
                } header: {
                    Text("Safety")
                } footer: {
                    Text("Blocking, reporting and removing all work from here and from any card.")
                }

                Section {
                    LabeledContent("Your name", value: winkName.isEmpty ? "Not set" : winkName)
                    LabeledContent("Cards kept", value: "\(moderation.received.count) received, \(moderation.sent.count) sent")
                } header: {
                    Text("This Device")
                } footer: {
                    Text("Nothing here leaves your phone. Cards travel straight to the other device over Nearby. There is no account and no server.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(WinkColor.night)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onClose)
                }
            }
        }
        .tint(WinkColor.volt)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSafety) {
            SafetyCenterView(moderation: moderation, onDismiss: { showSafety = false })
        }
        .sheet(isPresented: $showTerms) {
            TermsView()
        }
    }
}
