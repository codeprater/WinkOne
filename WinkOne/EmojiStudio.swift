import SwiftUI

/// One to three emoji. No text.
///
/// The picker carries every emoji the device can draw, grouped and searchable,
/// rather than the short hand picked list it started with.
struct EmojiStudio: View {
    @Binding var sequence: String
    @Binding var genmojiData: Data?
    var fromName: String
    var placeName: String?

    @State private var group = EmojiCatalog.groups.first?.name ?? "Smileys"
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 8)

    private var current: WinkMessage {
        WinkMessage(
            text: sequence,
            pack: "Emoji",
            atmosphere: Composer.emoji.atmosphere,
            ink: Composer.emoji.ink,
            placeName: placeName,
            emojiSequence: sequence.isEmpty ? nil : sequence,
            genmojiData: genmojiData
        )
    }

    private var isFull: Bool { sequence.count >= WinkLimits.maxEmoji }

    private var visible: [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return EmojiCatalog.matches(trimmed) }
        return EmojiCatalog.groups.first { $0.name == group }?.emoji ?? []
    }

    var body: some View {
        StudioLayout {
            WinkCardView(message: current, fromName: fromName)
        } controls: {
            VStack(spacing: 10) {
                chosenRow
                genmojiRow
                searchField
                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    groupRow
                }
                grid
            }
        }
    }

    // MARK: Pieces

    private var chosenRow: some View {
        HStack(spacing: 14) {
            Text(sequence.isEmpty ? "Pick up to three" : sequence)
                .font(.system(size: sequence.isEmpty ? 14 : 30))
                .foregroundStyle(sequence.isEmpty ? .white.opacity(0.4) : .white)
                .accessibilityLabel(
                    sequence.isEmpty ? "No emoji chosen" : "Chosen: \(sequence)"
                )

            if !sequence.isEmpty {
                Button {
                    sequence.removeLast()
                } label: {
                    Image(systemName: "delete.left.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(WinkColor.ember)
                }
                .accessibilityLabel("Remove the last emoji")
            }
        }
        .frame(height: 36)
    }

    /// Genmoji comes from the emoji keyboard, so this is a field to put it in
    /// rather than a button that makes one.
    @ViewBuilder
    private var genmojiRow: some View {
        if WinkAI.acceptsGenmoji {
            HStack(spacing: 10) {
                if genmojiData != nil {
                    Button {
                        genmojiData = nil
                    } label: {
                        Label("Remove Genmoji", systemImage: "trash")
                            .font(WinkFont.label(11))
                            .tracking(0.8)
                            .foregroundStyle(WinkColor.ember)
                    }
                    .accessibilityLabel("Remove the Genmoji")
                } else {
                    GenmojiField(
                        genmojiData: $genmojiData,
                        placeholder: "Tap here, then the emoji key, to make a Genmoji"
                    )
                    .frame(height: 44)
                }
            }
            .padding(.horizontal, 22)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
            TextField("Search emoji", text: $query)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .tint(WinkColor.volt)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($searchFocused)
                .submitLabel(.done)
            if !query.isEmpty {
                Button {
                    query = ""
                    searchFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.35))
                }
                .accessibilityLabel("Clear the search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.white.opacity(0.08)))
        .padding(.horizontal, 22)
    }

    private var groupRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(EmojiCatalog.groups) { item in
                    let on = item.name == group
                    Button {
                        group = item.name
                    } label: {
                        Image(systemName: item.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(on ? WinkColor.night : .white.opacity(0.55))
                            .frame(width: 40, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(on ? WinkColor.volt : Color.white.opacity(0.06))
                            )
                    }
                    .accessibilityLabel(item.name)
                    .accessibilityAddTraits(on ? [.isSelected] : [])
                }
            }
            .padding(.horizontal, 22)
        }
        .frame(height: 36)
    }

    @ViewBuilder
    private var grid: some View {
        if visible.isEmpty {
            Text("Nothing matches that.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.vertical, 18)
        } else {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(visible, id: \.self) { emoji in
                    Button {
                        append(emoji)
                    } label: {
                        Text(emoji)
                            .font(.system(size: 26))
                            .frame(width: 36, height: 36)
                            .opacity(isFull ? 0.35 : 1)
                    }
                    .disabled(isFull)
                    .accessibilityLabel(emoji)
                }
            }
            .padding(.horizontal, 18)
        }
    }

    private func append(_ emoji: String) {
        guard !isFull, let character = emoji.first, EmojiRules.isEmoji(character) else { return }
        sequence.append(emoji)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
