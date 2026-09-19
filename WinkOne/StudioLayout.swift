import SwiftUI

// MARK: - Shared card height

private struct WinkCardHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat = 400
}

extension EnvironmentValues {
    /// Every card on the main screen is this tall — deck cards and studio
    /// previews alike. ContentView measures it once from the space the dock
    /// leaves behind, so an Emoji card is exactly as big as a Stadium card.
    var winkCardHeight: CGFloat {
        get { self[WinkCardHeightKey.self] }
        set { self[WinkCardHeightKey.self] = newValue }
    }
}

// MARK: - Studio container

/// The frame every composer sits in.
///
/// Before this, each studio stacked a card and its controls in a plain VStack
/// with no height budget, so on a tall phone the emoji grid and swatch rows
/// spilled out of the card area and drew straight over the radar. The card now
/// gets a fixed share and the controls scroll inside what is left.
struct StudioLayout<Card: View, Controls: View>: View {
    @ViewBuilder var card: () -> Card
    @ViewBuilder var controls: () -> Controls

    @Environment(\.winkCardHeight) private var cardHeight

    var body: some View {
        VStack(spacing: 12) {
            card()
                .frame(height: cardHeight)
                .padding(.horizontal, 44)

            ScrollView(.vertical, showsIndicators: false) {
                controls()
                    .padding(.top, 2)
                    .padding(.bottom, 16)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipped()
    }
}
