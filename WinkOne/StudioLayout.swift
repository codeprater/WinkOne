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

    /// The controls get a ceiling and scroll inside it. Without one the
    /// ScrollView takes every spare point, the spacers collapse, and the card
    /// sits wherever it lands instead of in the middle.
    private let controlsCeiling: CGFloat = 340

    var body: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)

            card()
                .frame(height: cardHeight)
                .padding(.horizontal, 20)

            ScrollView(.vertical, showsIndicators: false) {
                controls()
                    .padding(.top, 2)
                    .padding(.bottom, 8)
            }
            .frame(maxHeight: controlsCeiling)
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 36) }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(maxWidth: .infinity, alignment: .center)
        .clipped()
    }
}
