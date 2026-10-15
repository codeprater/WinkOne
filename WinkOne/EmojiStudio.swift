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

    /// As many 50pt columns as the width allows. Eight fixed 54pt columns
    /// ran past the edge of every iPhone.
    private let columns = [GridItem(.adaptive(minimum: 50), spacing: 6)]

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
                .font(.system(size: sequence.isEmpty ? 16.0 : 36.0))
                .foregroundStyle(sequence.isEmpty ? .white.opacity(0.7) : .white)
                .accessibilityLabel(
                    sequence.isEmpty ? "No emoji chosen" : "Chosen: \(sequence)"
                )
                .frame(minHeight: 44.0)

            if !sequence.isEmpty {
                Button {
                    sequence.removeLast()
                } label: {
                    Image(systemName: "delete.left.fill")
                        .font(.system(size: 20.0, weight: .semibold))
                        .foregroundStyle(WinkColor.ember)
                        .frame(width: 44.0, height: 44.0)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Remove the last emoji")
                .accessibilityAddTraits([.isButton])
            }
        }
        .frame(height: 48.0)
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
                            .font(WinkFont.label(13))
                            .tracking(0.8)
                            .foregroundStyle(WinkColor.ember)
                            .frame(minWidth: 110.0, minHeight: 44.0)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Remove the Genmoji")
                    .accessibilityAddTraits([.isButton])
                } else {
                    GenmojiField(
                        genmojiData: $genmojiData,
                        placeholder: "Tap here, then the emoji key, to make a Genmoji"
                    )
                    .frame(height: 44.0)
                }
            }
            .padding(.horizontal, 22)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16.0, weight: .semibold))
                .foregroundStyle(.white.opacity(0.65))
                .frame(width: 44.0, height: 44.0)
                .contentShape(Rectangle())
            TextField("Search emoji", text: $query)
                .font(.system(size: 17.0, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .tint(WinkColor.volt)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($searchFocused)
                .submitLabel(.done)
                .frame(minHeight: 44.0)
            if !query.isEmpty {
                Button {
                    query = ""
                    searchFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.35))
                        .font(.system(size: 18.0))
                        .frame(width: 44.0, height: 44.0)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Clear the search")
                .accessibilityAddTraits([.isButton])
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.white.opacity(0.08)))
        .padding(.horizontal, 22)
    }

    private var groupRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(EmojiCatalog.groups) { item in
                    let on = item.name == group
                    let traits: AccessibilityTraits = on ? [.isButton, .isSelected] : [.isButton]
                    Button {
                        group = item.name
                    } label: {
                        Image(systemName: item.icon)
                            .font(.system(size: 17.0, weight: .semibold))
                            .foregroundStyle(on ? WinkColor.night : .white.opacity(0.75))
                            .frame(width: 44.0, height: 44.0)
                            .background(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(on ? WinkColor.volt : Color.white.opacity(0.06))
                            )
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(item.name)
                    .accessibilityAddTraits(traits)
                }
            }
            .padding(.horizontal, 22)
        }
        .frame(height: 52.0)
    }

    @ViewBuilder
    private var grid: some View {
        if visible.isEmpty {
            Text("Nothing matches that.")
                .font(.system(size: 15.0, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.vertical, 18)
        } else {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(visible, id: \.self) { emoji in
                    let disabled = isFull
                    Button {
                        append(emoji)
                    } label: {
                        Text(emoji)
                            .font(.system(size: 32.0))
                            .frame(width: 50.0, height: 50.0)
                            .opacity(disabled ? 0.35 : 1)
                            .contentShape(Rectangle())
                    }
                    .disabled(disabled)
                    .accessibilityLabel(emoji)
                    .accessibilityAddTraits([.isButton])
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

