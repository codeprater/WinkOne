import SwiftUI

/// The look every WINK card shares: a three-stop gradient with two soft
/// colour blooms laid over it, so no two inks read as the same card in a
/// different shade.
///
/// Apple Invites gets its richness from colours that do not belong to the same
/// family — a warm base with a cool bloom, or the reverse. Two `RadialGradient`
/// blooms on `.screen` do that cheaply and stay crisp at any card size, which a
/// baked image would not.
struct InviteBackdrop: View {
    let ink: CardInk

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let palette = ink.invitePalette

            ZStack {
                LinearGradient(
                    colors: palette.base,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [palette.bloomA.opacity(0.55), .clear],
                    center: .init(x: 0.18, y: 0.12),
                    startRadius: 0,
                    endRadius: max(w, h) * 0.78
                )
                .blendMode(.screen)

                RadialGradient(
                    colors: [palette.bloomB.opacity(0.42), .clear],
                    center: .init(x: 0.88, y: 0.86),
                    startRadius: 0,
                    endRadius: max(w, h) * 0.72
                )
                .blendMode(.screen)

                // A hairline of light along the top edge — the thing that reads
                // as "printed" rather than "filled with a colour".
                LinearGradient(
                    colors: [.white.opacity(0.14), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
                .blendMode(.softLight)
            }
        }
        .drawingGroup()
    }
}

extension CardInk {
    struct InvitePalette {
        let base: [Color]
        let bloomA: Color
        let bloomB: Color
    }

    /// Three-stop bases, each with two blooms from a *different* family. Volt
    /// stays bright because its type is dark; everything else runs deep so the
    /// volt type on top keeps its contrast.
    var invitePalette: InvitePalette {
        switch self {
        case .volt:
            InvitePalette(
                base: [hex("FFF07A"), hex("F7E90F"), hex("F2A81C")],
                bloomA: hex("FFFFFF"),
                bloomB: hex("FF7A3D")
            )
        case .ink:
            InvitePalette(
                base: [hex("0B0B10"), hex("1B1C27"), hex("2E2A40")],
                bloomA: hex("6C5CE7"),
                bloomB: hex("18C3B4")
            )
        case .gold:
            InvitePalette(
                base: [hex("140F04"), hex("3E2F0B"), hex("6E5111")],
                bloomA: hex("F7C63E"),
                bloomB: hex("B4472B")
            )
        case .field:
            InvitePalette(
                base: [hex("05130A"), hex("113A1E"), hex("1D5C2E")],
                bloomA: hex("A8E063"),
                bloomB: hex("1FA9A0")
            )
        case .wine:
            InvitePalette(
                base: [hex("1A0509"), hex("46111A"), hex("6E1B2C")],
                bloomA: hex("FF9A5B"),
                bloomB: hex("8E4BD0")
            )
        case .ember:
            InvitePalette(
                base: [hex("170604"), hex("4A1608"), hex("8A3110")],
                bloomA: hex("FFB347"),
                bloomB: hex("D9366E")
            )
        case .ice:
            InvitePalette(
                base: [hex("041014"), hex("0D2F38"), hex("155866")],
                bloomA: hex("8BE8E0"),
                bloomB: hex("5C7BF0")
            )
        case .kraft:
            InvitePalette(
                base: [hex("14120E"), hex("2B2620"), hex("463C2E")],
                bloomA: hex("E8D9B6"),
                bloomB: hex("7A9A6B")
            )
        }
    }

    private func hex(_ value: String) -> Color { Color(winkHex: value) }
}
