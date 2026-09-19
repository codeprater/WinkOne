import SwiftUI

/// The twelve signs, each with its own gradient. Colors are picked per sign —
/// fire runs warm, water cool, earth grounded, air pale — so a Leo and a Pisces
/// never look like the same card in a different font.
enum Zodiac: String, CaseIterable, Identifiable, Codable, Hashable {
    case aries = "Aries"
    case taurus = "Taurus"
    case gemini = "Gemini"
    case cancer = "Cancer"
    case leo = "Leo"
    case virgo = "Virgo"
    case libra = "Libra"
    case scorpio = "Scorpio"
    case sagittarius = "Sagittarius"
    case capricorn = "Capricorn"
    case aquarius = "Aquarius"
    case pisces = "Pisces"

    var id: String { rawValue }

    /// The glyph, from SF Symbols' zodiac set.
    var symbol: String {
        switch self {
        case .aries: "aries"
        case .taurus: "taurus"
        case .gemini: "gemini"
        case .cancer: "cancer"
        case .leo: "leo"
        case .virgo: "virgo"
        case .libra: "libra"
        case .scorpio: "scorpio"
        case .sagittarius: "sagittarius"
        case .capricorn: "capricorn"
        case .aquarius: "aquarius"
        case .pisces: "pisces"
        }
    }

    var element: String {
        switch self {
        case .aries, .leo, .sagittarius: "Fire"
        case .taurus, .virgo, .capricorn: "Earth"
        case .gemini, .libra, .aquarius: "Air"
        case .cancer, .scorpio, .pisces: "Water"
        }
    }

    var dates: String {
        switch self {
        case .aries: "Mar 21 to Apr 19"
        case .taurus: "Apr 20 to May 20"
        case .gemini: "May 21 to Jun 20"
        case .cancer: "Jun 21 to Jul 22"
        case .leo: "Jul 23 to Aug 22"
        case .virgo: "Aug 23 to Sep 22"
        case .libra: "Sep 23 to Oct 22"
        case .scorpio: "Oct 23 to Nov 21"
        case .sagittarius: "Nov 22 to Dec 21"
        case .capricorn: "Dec 22 to Jan 19"
        case .aquarius: "Jan 20 to Feb 18"
        case .pisces: "Feb 19 to Mar 20"
        }
    }

    /// A one-liner the card can carry when the sender writes nothing.
    var line: String {
        switch self {
        case .aries: "First through the door."
        case .taurus: "Not moving. Bring snacks."
        case .gemini: "Two minds, one text."
        case .cancer: "Soft outside too, actually."
        case .leo: "You saw me. Good."
        case .virgo: "I fixed it while you slept."
        case .libra: "Let's split the difference."
        case .scorpio: "I remember everything."
        case .sagittarius: "Already outside."
        case .capricorn: "On the schedule."
        case .aquarius: "Not like the others."
        case .pisces: "Somewhere else, mostly."
        }
    }

    /// Three stops, so the card has depth rather than a flat two-color ramp.
    var gradient: [Color] {
        switch self {
        case .aries:       Zodiac.mix("2B0A06", "B3310C", "F2662A")
        case .taurus:      Zodiac.mix("0F1A0C", "2E5127", "8FB45A")
        case .gemini:      Zodiac.mix("1A1630", "4B3E8F", "C9A6F2")
        case .cancer:      Zodiac.mix("0A1620", "1F4A63", "9FD6E8")
        case .leo:         Zodiac.mix("2A1602", "9A5E05", "F7C63E")
        case .virgo:       Zodiac.mix("14180F", "3F4A2E", "AFBE83")
        case .libra:       Zodiac.mix("221324", "6B3A63", "E2A8CE")
        case .scorpio:     Zodiac.mix("16060F", "5C0E33", "C43A6B")
        case .sagittarius: Zodiac.mix("240C1C", "7A2352", "F2795E")
        case .capricorn:   Zodiac.mix("101315", "353E44", "8E9AA3")
        case .aquarius:    Zodiac.mix("061821", "0F5566", "5FE0D2")
        case .pisces:      Zodiac.mix("0C1226", "2B3E82", "93B4F5")
        }
    }

    /// Ink that reads on that sign's darkest stop.
    var ink: Color {
        switch self {
        case .leo, .taurus, .virgo, .aquarius: Color(winkHex: "FFF8E6")
        default: Color(winkHex: "FDF3F6")
        }
    }

    var accent: Color { gradient.last ?? WinkColor.volt }

    private static func mix(_ a: String, _ b: String, _ c: String) -> [Color] {
        [Color(winkHex: a), Color(winkHex: b), Color(winkHex: c)]
    }

    static func named(_ raw: String?) -> Zodiac? {
        guard let raw else { return nil }
        return Zodiac(rawValue: raw)
    }
}

// MARK: - Studio

/// Pick a sign, optionally say something. The card is the sign.
struct ZodiacStudio: View {
    @Binding var sign: String
    @Binding var caption: String
    var fromName: String
    var placeName: String?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    private var selected: Zodiac { Zodiac(rawValue: sign) ?? .aries }

    private var current: WinkMessage {
        WinkMessage(
            text: caption,
            pack: "Zodiac",
            atmosphere: Composer.zodiac.atmosphere,
            ink: Composer.zodiac.ink,
            placeName: placeName,
            zodiacSign: sign
        )
    }

    var body: some View {
        StudioLayout {
            WinkCardView(message: current, fromName: fromName)
        } controls: {
            VStack(spacing: 14) {
                TextField(selected.line, text: $caption)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .tint(selected.accent)
                    .padding(.horizontal, 30)
                    .winkWritingTools()
                    .onChange(of: caption) { _, newValue in
                        if newValue.count > WinkLimits.zodiacCaption {
                            caption = String(newValue.prefix(WinkLimits.zodiacCaption))
                        }
                    }
                    .accessibilityLabel("Caption for your zodiac wink")

                SuggestLinesRow(
                    composerName: "Zodiac",
                    seed: selected.rawValue,
                    target: $caption
                )

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Zodiac.allCases) { item in
                        Button {
                            sign = item.rawValue
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: item.symbol)
                                    .font(.system(size: 20, weight: .semibold))
                                Text(item.rawValue.uppercased())
                                    .font(WinkFont.label(8))
                                    .tracking(0.6)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .foregroundStyle(item == selected ? WinkColor.night : item.accent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(
                                        item == selected
                                            ? AnyShapeStyle(LinearGradient(colors: item.gradient.suffix(2), startPoint: .topLeading, endPoint: .bottomTrailing))
                                            : AnyShapeStyle(Color.white.opacity(0.06))
                                    )
                            )
                        }
                        .accessibilityLabel(item.rawValue)
                        .accessibilityValue("\(item.element) sign, \(item.dates)")
                        .accessibilityAddTraits(item == selected ? [.isSelected] : [])
                    }
                }
                .padding(.horizontal, 22)
            }
        }
    }
}
