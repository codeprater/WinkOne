import SwiftUI

/// One to three emoji. No text. The grid covers the common cases; the keyboard
/// handles everything else, filtered down to emoji on the way in.
struct EmojiStudio: View {
    @Binding var sequence: String
    var fromName: String
    var placeName: String?

    @State private var keyboardEntry = ""
    @FocusState private var keyboardFocused: Bool

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 10)

    private var current: WinkMessage {
        WinkMessage(
            text: sequence,
            pack: "Emoji",
            atmosphere: Composer.emoji.atmosphere,
            ink: Composer.emoji.ink,
            placeName: placeName,
            emojiSequence: sequence.isEmpty ? nil : sequence
        )
    }

    private var isFull: Bool { sequence.count >= WinkLimits.maxEmoji }

    var body: some View {
        StudioLayout {
            WinkCardView(message: current, fromName: fromName)
        } controls: {
            VStack(spacing: 12) {
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
            .frame(height: 40)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(EmojiRules.common, id: \.self) { emoji in
                    Button {
                        append(emoji)
                    } label: {
                        Text(emoji)
                            .font(.system(size: 24))
                            .frame(width: 34, height: 34)
                            .opacity(isFull ? 0.35 : 1)
                    }
                    .disabled(isFull)
                    .accessibilityLabel(emoji)
                }
            }
            .padding(.horizontal, 18)

            TextField("Or type any emoji", text: $keyboardEntry)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.75))
                .tint(WinkColor.volt)
                .focused($keyboardFocused)
                .padding(.horizontal, 36)
                .onChange(of: keyboardEntry) { _, newValue in
                    let cleaned = EmojiRules.sanitize(newValue)
                    if !cleaned.isEmpty {
                        sequence = cleaned
                    }
                    if newValue != cleaned {
                        keyboardEntry = cleaned
                    }
                }
                .accessibilityLabel("Type emoji from the keyboard")
                .accessibilityHint("Anything that is not an emoji is ignored")
            }
        }
    }

    private func append(_ emoji: String) {
        guard !isFull, let character = emoji.first, EmojiRules.isEmoji(character) else { return }
        sequence.append(emoji)
        keyboardEntry = sequence
    }
}
