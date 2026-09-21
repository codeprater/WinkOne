import SwiftUI

enum InviteCard {
    /// Apple Invites-style portrait card (3:4).
    static let aspectRatio: CGFloat = 3.0 / 4.0
    static let cornerRadius: CGFloat = 26
    static let renderWidth: CGFloat = 390
    static var renderHeight: CGFloat { renderWidth / aspectRatio }
}

enum WinkFont {
    static func brand(_ size: CGFloat) -> Font {
        .custom("Futura-Bold", size: size)
    }

    static func shout(_ size: CGFloat) -> Font {
        .custom("Futura-Bold", size: size)
    }

    static func label(_ size: CGFloat) -> Font {
        .custom("AvenirNext-Bold", size: size)
    }

    static func body(_ size: CGFloat) -> Font {
        .custom("AvenirNext-DemiBold", size: size)
    }
}

enum WinkColor {
    static let volt = Color(red: 0.97, green: 0.92, blue: 0.12)
    static let night = Color(red: 0.05, green: 0.05, blue: 0.05)
    static let asphalt = Color(red: 0.08, green: 0.09, blue: 0.08)
    static let field = Color(red: 0.07, green: 0.16, blue: 0.10)
    static let wine = Color(red: 0.22, green: 0.06, blue: 0.08)
    static let ember = Color(red: 0.86, green: 0.29, blue: 0.08)
    static let ice = Color(red: 0.55, green: 0.86, blue: 0.84)
    static let kraft = Color(red: 0.14, green: 0.13, blue: 0.11)
    static let bone = Color(red: 0.93, green: 0.90, blue: 0.84)
}

enum CardInk: String, Codable, Hashable {
    case volt, ink, gold, field, wine, ember, ice, kraft, coral, lavender, ocean, mint, rose, sky, tangerine, plum

    var fill: Color {
        switch self {
        case .volt: WinkColor.volt
        case .ink: WinkColor.night
        case .gold: Color(red: 0.12, green: 0.10, blue: 0.04)
        case .field: WinkColor.field
        case .wine: WinkColor.wine
        case .ember: Color(red: 0.12, green: 0.05, blue: 0.02)
        case .ice: Color(red: 0.04, green: 0.10, blue: 0.12)
        case .kraft: WinkColor.kraft
        case .coral: Color(red: 0.32, green: 0.07, blue: 0.08)
        case .lavender: Color(red: 0.17, green: 0.10, blue: 0.28)
        case .ocean: Color(red: 0.03, green: 0.14, blue: 0.28)
        case .mint: Color(red: 0.04, green: 0.22, blue: 0.18)
        case .rose: Color(red: 0.28, green: 0.08, blue: 0.18)
        case .sky: Color(red: 0.06, green: 0.22, blue: 0.34)
        case .tangerine: Color(red: 0.32, green: 0.13, blue: 0.02)
        case .plum: Color(red: 0.22, green: 0.05, blue: 0.24)
        }
    }

    var type: Color {
        switch self {
        case .volt: WinkColor.night
        case .ink, .gold, .field, .wine, .ember, .ice, .kraft, .coral, .lavender, .ocean, .mint, .rose, .sky, .tangerine, .plum: WinkColor.volt
        }
    }

    var accent: Color {
        switch self {
        case .volt: WinkColor.night
        case .ink: WinkColor.volt
        case .gold: WinkColor.volt
        case .field: Color(red: 0.85, green: 0.92, blue: 0.45)
        case .wine: Color(red: 1.0, green: 0.62, blue: 0.28)
        case .ember: WinkColor.ember
        case .ice: WinkColor.ice
        case .kraft: WinkColor.bone
        case .coral: Color(red: 1.0, green: 0.56, blue: 0.48)
        case .lavender: Color(red: 0.82, green: 0.68, blue: 1.0)
        case .ocean: Color(red: 0.45, green: 0.82, blue: 1.0)
        case .mint: Color(red: 0.42, green: 1.0, blue: 0.72)
        case .rose: Color(red: 1.0, green: 0.52, blue: 0.72)
        case .sky: Color(red: 0.48, green: 0.86, blue: 1.0)
        case .tangerine: Color(red: 1.0, green: 0.72, blue: 0.28)
        case .plum: Color(red: 0.92, green: 0.52, blue: 1.0)
        }
    }
}
