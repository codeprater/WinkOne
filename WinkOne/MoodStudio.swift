import SwiftUI

/// One color, one word. No caption, no symbol — the constraint is the product.
struct MoodStudio: View {
    @Binding var colorHex: String
    @Binding var word: String
    var fromName: String
    var placeName: String?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)

    private var current: WinkMessage {
        WinkMessage(
            text: word,
            pack: "Mood",
            atmosphere: Composer.mood.atmosphere,
            ink: Composer.mood.ink,
            placeName: placeName,
            moodColorHex: colorHex,
            moodWord: word.isEmpty ? nil : word
        )
    }

    var body: some View {
        StudioLayout {
            WinkCardView(message: current, fromName: fromName)
        } controls: {
            VStack(spacing: 16) {
            TextField("One word", text: $word)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .tint(WinkColor.volt)
                .textInputAutocapitalization(.characters)
                .winkWritingTools(full: false)
                .padding(.horizontal, 36)
                .onChange(of: word) { _, newValue in
                    // One word means one word — collapse anything past the first.
                    let firstWord = newValue.split(separator: " ").first.map(String.init) ?? newValue
                    let trimmed = String(firstWord.prefix(WinkLimits.moodWord))
                    if trimmed != newValue { word = trimmed }
                }
                .accessibilityLabel("The one word on your mood card")

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(MoodPalette.swatches, id: \.hex) { swatch in
                    Button {
                        colorHex = swatch.hex
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(winkHex: swatch.hex))
                                .frame(width: 40, height: 40)
                            Circle()
                                .stroke(
                                    colorHex.caseInsensitiveCompare(swatch.hex) == .orderedSame
                                        ? WinkColor.volt : Color.white.opacity(0.18),
                                    lineWidth: colorHex.caseInsensitiveCompare(swatch.hex) == .orderedSame ? 3 : 1
                                )
                                .frame(width: 46, height: 46)
                        }
                        .frame(height: 50)
                    }
                    .accessibilityLabel(swatch.name)
                    .accessibilityAddTraits(
                        colorHex.caseInsensitiveCompare(swatch.hex) == .orderedSame ? [.isSelected] : []
                    )
                }
            }
            .padding(.horizontal, 30)

            Text("A color and a word. Nothing else to say.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.42))
            }
        }
    }
}
