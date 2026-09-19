import SwiftUI

/// Everything that has landed on this device. Until 2.0 the received list was
/// buried inside Safety Center; it now has its own place in the dock.
struct InboxView: View {
    @ObservedObject var moderation: ModerationStore
    var onReport: (ReceivedWink) -> Void
    var onDismiss: () -> Void

    @State private var opened: ReceivedWink?

    var body: some View {
        NavigationStack {
            Group {
                if moderation.received.isEmpty {
                    empty
                } else {
                    list
                }
            }
            .navigationTitle("Inbox")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDismiss)
                }
                if !moderation.received.isEmpty {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Clear", role: .destructive) {
                            moderation.removeAllReceived()
                        }
                        .accessibilityHint("Removes every wink from this device")
                    }
                }
            }
            .sheet(item: $opened) { wink in
                InboxCardView(wink: wink) { opened = nil }
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 12) {
            Image(systemName: WinkSymbol.inbox)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)
            Text("Nothing yet")
                .font(.system(size: 19, weight: .semibold, design: .rounded))
            Text("Winks people send you land here. Everything stays on this device.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 44)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        List {
            Section {
                ForEach(moderation.received) { wink in
                    Button {
                        opened = wink
                    } label: {
                        InboxRow(wink: wink)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("Remove", role: .destructive) {
                            moderation.remove(wink)
                        }
                        Button("Report") { onReport(wink) }
                            .tint(.orange)
                    }
                }
                .onDelete { moderation.removeReceived(at: $0) }
            } footer: {
                Text("Swipe any wink to remove or report it. Removal is immediate and permanent on this device.")
            }
        }
    }
}

private struct InboxRow: View {
    let wink: ReceivedWink

    private var kindLabel: String {
        let p = wink.payload
        if p.voiceData != nil { return "Voice" }
        if p.photoData != nil { return "Photo" }
        if p.moodColorHex != nil { return "Mood" }
        if p.emojiSequence != nil { return "Emoji" }
        if p.drawingData != nil { return "Handwritten" }
        if p.atmosphere == "Links" { return "Link" }
        return p.pack
    }

    private var preview: String {
        let p = wink.payload
        if let emoji = p.emojiSequence { return emoji }
        if let word = p.moodWord { return word }
        if let caption = p.photoCaption, !caption.isEmpty { return caption }
        return p.text.isEmpty ? (p.symbolName ?? "Card") : p.text
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(wink.fromName)
                    .font(.system(size: 15, weight: .semibold))
                Text(preview)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text("\(kindLabel) · \(wink.date, style: .relative) ago")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
            if wink.payload.secretUntilTapped {
                Image(systemName: "eye.slash.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Was sent as a secret")
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }

    private var icon: String {
        let p = wink.payload
        if p.voiceData != nil { return "waveform" }
        if p.photoData != nil { return "photo.fill" }
        if p.moodColorHex != nil { return "circle.fill" }
        if p.emojiSequence != nil { return "face.smiling.inverse" }
        if p.drawingData != nil { return "pencil.and.scribble" }
        if p.atmosphere == "Links" { return "link" }
        return p.symbolName ?? "rectangle.portrait"
    }
}

/// Re-reads a stored wink. Already-revealed secrets stay revealed — the blur
/// state is deliberately not persisted.
private struct InboxCardView: View {
    let wink: ReceivedWink
    var onClose: () -> Void

    var body: some View {
        ZStack {
            WinkColor.night.ignoresSafeArea()
            VStack(spacing: 18) {
                Text(wink.fromName.uppercased())
                    .font(WinkFont.label(12))
                    .tracking(2)
                    .foregroundStyle(WinkColor.volt)

                WinkCardView(message: wink.payload.asMessage, fromName: wink.fromName)
                    .padding(.horizontal, 36)

                Button("CLOSE", action: onClose)
                    .font(WinkFont.label(13))
                    .tracking(1.6)
                    .foregroundStyle(.white)
            }
        }
    }
}
