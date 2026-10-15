import SwiftUI

enum WatchColor {
    nonisolated static let volt = Color(red: 0.97, green: 0.92, blue: 0.12)
    nonisolated static let night = Color(red: 0.05, green: 0.05, blue: 0.05)
}

/// The short lines a watch can send. Typed on a phone they would be anything;
/// on a wrist they are a tap. Dictation covers the rest.
struct QuickLine: Identifiable, Hashable {
    let symbol: String
    let text: String
    var id: String { text }

    static let all: [QuickLine] = [
        QuickLine(symbol: "hand.wave.fill", text: "Hey there"),
        QuickLine(symbol: "hand.thumbsup.fill", text: "Nice one"),
        QuickLine(symbol: "face.smiling", text: "You made my day"),
        QuickLine(symbol: "cup.and.saucer.fill", text: "Coffee?"),
        QuickLine(symbol: "figure.wave", text: "Over here"),
        QuickLine(symbol: "sparkles", text: "Love your style"),
        QuickLine(symbol: "checkmark.circle.fill", text: "Got it"),
        QuickLine(symbol: "heart.fill", text: "Thank you")
    ]
}

// MARK: - Root

struct WatchRootView: View {
    @EnvironmentObject private var store: WatchStore

    var body: some View {
        NavigationStack {
            List {
                if let state = store.state {
                    Section {
                        NavigationLink {
                            PeerListView()
                        } label: {
                            Label("Send a WINK", systemImage: "paperplane.fill")
                                .font(.headline)
                                .foregroundStyle(WatchColor.volt)
                        }

                        Button {
                            store.send(WatchCommand(kind: .ghost))
                        } label: {
                            Label(
                                state.discoverable ? "Visible" : "Ghost Mode",
                                systemImage: state.discoverable ? "antenna.radiowaves.left.and.right" : "eye.slash"
                            )
                        }
                        .accessibilityHint(state.discoverable ? "Turns on Ghost Mode" : "Makes you visible again")
                    }

                    Section("Inbox") {
                        if store.winks.isEmpty {
                            Text("No winks yet.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(store.winks) { wink in
                            NavigationLink {
                                WinkDetailView(wink: wink)
                            } label: {
                                InboxRow(wink: wink)
                            }
                        }
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "iphone")
                            .font(.title2)
                        Text("Open WINK on your iPhone to connect.")
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("WINK")
            .overlay(alignment: .bottom) { NoticeBanner() }
        }
        .onAppear { store.refresh() }
    }
}

struct InboxRow: View {
    let wink: WatchWink

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(wink.moodHex.map(Color.init(watchHex:)) ?? WatchColor.volt)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(wink.fromName)
                    .font(.headline)
                    .lineLimit(1)
                Text(wink.secret ? "Secret WINK" : (wink.text.isEmpty ? wink.kind : wink.text))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Detail

struct WinkDetailView: View {
    @EnvironmentObject private var store: WatchStore
    @Environment(\.dismiss) private var dismiss
    let wink: WatchWink

    @State private var revealed = false
    @State private var confirmReport = false
    @State private var confirmBlock = false

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if wink.secret && !revealed {
                    Button {
                        revealed = true
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "eye.slash.fill").font(.title2)
                            Text("Tap to reveal").font(.headline)
                        }
                        .frame(maxWidth: .infinity, minHeight: 120)
                    }
                    .buttonStyle(.bordered)
                } else {
                    WatchCardView(wink: wink)
                }

                Text("From \(wink.fromName)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                NavigationLink {
                    QuickLineView(title: "Wink back") { line in
                        store.send(WatchCommand(kind: .reply, winkID: wink.id, text: line.text, symbolName: line.symbol))
                    }
                } label: {
                    Label("Wink back", systemImage: "arrowshape.turn.up.left.fill")
                        .foregroundStyle(WatchColor.night)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    store.send(WatchCommand(kind: .remove, winkID: wink.id))
                    dismiss()
                } label: {
                    Label("Remove", systemImage: "trash").frame(maxWidth: .infinity)
                }

                Button {
                    confirmReport = true
                } label: {
                    Label("Report", systemImage: "exclamationmark.bubble").frame(maxWidth: .infinity)
                }

                Button(role: .destructive) {
                    confirmBlock = true
                } label: {
                    Label("Block \(wink.fromName)", systemImage: "hand.raised.fill").frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle(wink.kind)
        .confirmationDialog("Report this WINK?", isPresented: $confirmReport, titleVisibility: .visible) {
            Button("Report and remove", role: .destructive) {
                store.send(WatchCommand(kind: .report, winkID: wink.id))
                dismiss()
            }
        } message: {
            Text("It goes to the Safety Center on your iPhone.")
        }
        .confirmationDialog("Block \(wink.fromName)?", isPresented: $confirmBlock, titleVisibility: .visible) {
            Button("Block", role: .destructive) {
                store.send(WatchCommand(kind: .block, winkID: wink.id))
                dismiss()
            }
        } message: {
            Text("They will not be able to find you or send you winks.")
        }
    }
}

struct WatchCardView: View {
    let wink: WatchWink

    private var background: Color {
        wink.moodHex.map(Color.init(watchHex:)) ?? Color(white: 0.14)
    }

    private var ink: Color {
        guard let hex = wink.moodHex else { return .white }
        return Color.watchIsLight(hex: hex) ? .black : .white
    }

    var body: some View {
        VStack(spacing: 8) {
            if let emoji = wink.emoji, !emoji.isEmpty {
                Text(emoji).font(.system(size: 40))
            } else if let symbol = wink.symbolName {
                Image(systemName: symbol)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(wink.moodHex == nil ? WatchColor.volt : ink)
            } else if let sign = wink.zodiac {
                Image(systemName: sign.lowercased())
                    .font(.system(size: 30, weight: .semibold))
            }

            if !wink.text.isEmpty {
                Text(wink.text)
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }

            if wink.hasPhoto {
                Label("Photo on your iPhone", systemImage: "photo").font(.caption2)
            }
            if wink.hasVoice {
                Label("Play it on your iPhone", systemImage: "waveform").font(.caption2)
            }

            Text(wink.kind.uppercased())
                .font(.caption2.weight(.bold))
                .opacity(0.75)
        }
        .foregroundStyle(ink)
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(background))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Sending

struct PeerListView: View {
    @EnvironmentObject private var store: WatchStore

    var body: some View {
        List {
            let peers = store.state?.peers ?? []
            if peers.isEmpty {
                Text("No one nearby. They need WINK open on their iPhone too.")
                    .foregroundStyle(.secondary)
            }
            ForEach(peers) { peer in
                if peer.locked {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(peer.name).font(.headline)
                        Text("Waiting for a wink back").font(.footnote).foregroundStyle(.secondary)
                    }
                } else {
                    NavigationLink {
                        QuickLineView(title: peer.name) { line in
                            store.send(WatchCommand(kind: .send, peerID: peer.id, text: line.text, symbolName: line.symbol))
                        }
                    } label: {
                        Label(peer.name, systemImage: "figure.stand")
                    }
                }
            }
        }
        .navigationTitle("Nearby")
        .overlay(alignment: .bottom) { NoticeBanner() }
    }
}

/// Pick a line, or say one. Whatever is said still runs through the content
/// filter on the phone before it goes anywhere.
struct QuickLineView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let onPick: (QuickLine) -> Void

    @State private var spoken = ""

    var body: some View {
        List {
            TextField("Say something", text: $spoken)
                .onSubmit {
                    let text = String(spoken.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
                    guard !text.isEmpty else { return }
                    pick(QuickLine(symbol: "bubble.left.fill", text: text))
                }

            ForEach(QuickLine.all) { line in
                Button {
                    pick(line)
                } label: {
                    Label(line.text, systemImage: line.symbol)
                }
            }
        }
        .navigationTitle(title)
    }

    private func pick(_ line: QuickLine) {
        onPick(line)
        dismiss()
    }
}

struct NoticeBanner: View {
    @EnvironmentObject private var store: WatchStore

    var body: some View {
        if let notice = store.notice {
            Text(notice)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(WatchColor.night)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(WatchColor.volt))
                .transition(.opacity)
        }
    }
}

// MARK: - Color

extension Color {
    /// Pure value math, so it is safe from any context.
    nonisolated init(watchHex hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let raw = UInt32(value, radix: 16) else {
            self = WatchColor.volt
            return
        }
        self = Color(
            red: Double((raw & 0xFF0000) >> 16) / 255,
            green: Double((raw & 0x00FF00) >> 8) / 255,
            blue: Double(raw & 0x0000FF) / 255
        )
    }

    nonisolated static func watchIsLight(hex: String) -> Bool {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let raw = UInt32(value, radix: 16) else { return true }
        let r = Double((raw & 0xFF0000) >> 16) / 255
        let g = Double((raw & 0x00FF00) >> 8) / 255
        let b = Double(raw & 0x0000FF) / 255
        return (0.2126 * r + 0.7152 * g + 0.0722 * b) > 0.55
    }
}
