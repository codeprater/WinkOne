import SwiftUI

// MARK: - Studio container

/// The frame every composer sits in: the card on top, the tools underneath.
///
/// It measures the space it is actually given instead of reading one height
/// computed elsewhere. The card may take at most `cardShare` of that space;
/// everything below it belongs to the tools, in a panel that scrolls when a
/// studio has more controls than fit. The tools can never be pushed off the
/// screen by the card again.
struct StudioLayout<Card: View, Controls: View>: View {
    @ViewBuilder var card: () -> Card
    @ViewBuilder var controls: () -> Controls

    /// The most of the height the card preview may take.
    private let cardShare: CGFloat = 0.46
    /// The card never shrinks past this, even with the keyboard up.
    private let cardFloor: CGFloat = 150

    var body: some View {
        GeometryReader { geo in
            let byWidth = (geo.size.width - 64) / InviteCard.aspectRatio
            let cardHeight = max(cardFloor, min(geo.size.height * cardShare, byWidth))

            VStack(spacing: 10) {
                card()
                    .aspectRatio(InviteCard.aspectRatio, contentMode: .fit)
                    .frame(height: cardHeight)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)

                ScrollView(.vertical) {
                    controls()
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                        .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.visible)
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)
                .background(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 24,
                        topTrailingRadius: 24,
                        style: .continuous
                    )
                    .fill(Color.white.opacity(0.06))
                )
                .padding(.horizontal, 8)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Card tools")
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
    }
}
