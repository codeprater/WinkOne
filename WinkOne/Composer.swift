import SwiftUI

// MARK: - Composer

/// One source of truth for what can be composed.
///
/// Before 2.0 the app branched on the `selectedAtmosphere` string in two
/// separate places — `cardDeck` (which studio to show) and `currentCard`
/// (which model to build). Every new composer meant editing both. This enum
/// collapses that into a single switch each.
enum Composer: String, CaseIterable, Identifiable, Hashable {
    case stadium     = "Stadium"
    case lounge      = "Lounge"
    case dailyGrind  = "Daily Grind"
    case genZ        = "Gen-Z"
    case symbols     = "Symbols"
    case handwritten = "Handwritten"
    case links       = "Links"
    case voice       = "Voice"
    case photo       = "Photo"
    case mood        = "Mood"
    case emoji       = "Emoji"
    case zodiac      = "Zodiac"

    var id: String { rawValue }

    /// The atmosphere string stored on cards and advertised to peers.
    var atmosphere: String { rawValue }

    init(atmosphere: String) {
        self = Composer(rawValue: atmosphere) ?? .stadium
    }

    /// Deck-backed composers page through fixed cards. The rest present a studio
    /// in place of the card deck.
    var isDeck: Bool {
        switch self {
        case .stadium, .lounge, .dailyGrind, .genZ: true
        default: false
        }
    }

    /// Studios manage their own layout and must not get the deck's padding.
    var isStudio: Bool { !isDeck }

    var ink: CardInk {
        switch self {
        case .symbols: .volt
        case .links: .ice
        case .handwritten: .gold
        case .voice: .ember
        case .photo: .ink
        case .mood: .volt
        case .emoji: .kraft
        case .zodiac: .ink
        case .stadium, .lounge, .dailyGrind, .genZ: .gold
        }
    }

    var icon: String {
        switch self {
        case .stadium: "sportscourt.fill"
        case .lounge: "wineglass.fill"
        case .dailyGrind: "cup.and.saucer.fill"
        case .genZ: "bolt.fill"
        case .symbols: "square.grid.2x2.fill"
        case .handwritten: "pencil.and.scribble"
        case .links: "link"
        case .voice: "waveform"
        case .photo: "photo.fill"
        case .mood: "circle.fill"
        case .emoji: "face.smiling.inverse"
        case .zodiac: "sparkles"
        }
    }

    var line: String {
        switch self {
        case .stadium: "Gameday energy"
        case .lounge: "Bars & nights out"
        case .dailyGrind: "Cafe, campus, work"
        case .genZ: "Slang. Unmuted."
        case .symbols: "Caption any SF Symbol"
        case .handwritten: "Pencil or finger"
        case .links: "Paste a link and send"
        case .voice: "Three seconds, out loud"
        case .photo: "One picture, no metadata"
        case .mood: "One color, one word"
        case .emoji: "Up to three, nothing else"
        case .zodiac: "All twelve signs"
        }
    }
}

// MARK: - Limits

/// Every hard cap in one place so the studios, the filter and the transport
/// agree. Binary fields are base64 on the wire, which inflates them by roughly
/// a third — `maxWireBytes` accounts for that.
enum WinkLimits {
    /// 3 s of mono AAC at 64 kbps is about 24 KB. Four times headroom.
    nonisolated static let maxVoiceBytes = 96_000
    nonisolated static let maxVoiceSeconds: TimeInterval = 3.0

    /// Per spec. 1200 px long edge at quality 0.75 lands well under this.
    nonisolated static let maxPhotoBytes = 1_500_000
    nonisolated static let photoLongEdge: CGFloat = 1200
    nonisolated static let photoQuality: CGFloat = 0.75

    nonisolated static let maxDrawingBytes = 512_000

    /// Whole-JSON ceiling on the wire. A 1.5 MB photo becomes ~2 MB base64,
    /// so a 2 MB cap would reject a legal card.
    nonisolated static let maxWireBytes = 4_000_000

    // Text caps
    nonisolated static let symbolCaption = 40
    nonisolated static let handwrittenCaption = 48
    nonisolated static let linkText = 240
    nonisolated static let photoCaption = 60
    nonisolated static let moodWord = 24
    nonisolated static let zodiacCaption = 44
    nonisolated static let maxEmoji = 3
}

// MARK: - Mood palette

/// Twelve fixed swatches drawn from Theme.swift. Deliberately not a color
/// wheel — the constraint is the point.
enum MoodPalette {
    static let swatches: [(name: String, hex: String)] = [
        ("Volt",    "F7EB1F"),
        ("Night",   "0D0D0D"),
        ("Ember",   "DB4A14"),
        ("Ice",     "8CDBD6"),
        ("Field",   "12291A"),
        ("Wine",    "380F14"),
        ("Kraft",   "24211C"),
        ("Bone",    "EDE5D6"),
        ("Asphalt", "141714"),
        ("Gold",    "1F1A0A"),
        ("Signal",  "FC7A1E"),
        ("Deep",    "0A1A2F")
    ]

    static let defaultHex = "F7EB1F"

    static func name(for hex: String) -> String {
        swatches.first { $0.hex.caseInsensitiveCompare(hex) == .orderedSame }?.name ?? "Color"
    }
}

extension Color {
    /// Six-digit RRGGBB, with or without a leading #. Falls back to the volt
    /// yellow rather than trapping on malformed input from the wire.
    init(winkHex hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let raw = UInt32(value, radix: 16) else {
            self = WinkColor.volt
            return
        }
        self = Color(
            red: Double((raw & 0xFF0000) >> 16) / 255,
            green: Double((raw & 0x00FF00) >> 8) / 255,
            blue: Double(raw & 0x0000FF) / 255
        )
    }

    /// Rough relative luminance, used to pick readable ink on a mood card.
    static func winkIsLight(hex: String) -> Bool {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let raw = UInt32(value, radix: 16) else { return true }
        let r = Double((raw & 0xFF0000) >> 16) / 255
        let g = Double((raw & 0x00FF00) >> 8) / 255
        let b = Double(raw & 0x0000FF) / 255
        return (0.2126 * r + 0.7152 * g + 0.0722 * b) > 0.55
    }
}

// MARK: - Emoji validation

enum EmojiRules {
    /// True when every character in the string is emoji and there are 1...3 of them.
    nonisolated static func isValid(_ text: String) -> Bool {
        let chars = Array(text)
        guard !chars.isEmpty, chars.count <= WinkLimits.maxEmoji else { return false }
        return chars.allSatisfy(isEmoji)
    }

    nonisolated static func isEmoji(_ character: Character) -> Bool {
        guard let first = character.unicodeScalars.first else { return false }
        if character.unicodeScalars.count > 1 {
            return character.unicodeScalars.contains { $0.properties.isEmoji }
        }
        return first.properties.isEmoji && first.value > 0x238C
    }

    /// Keeps only emoji, then trims to the first three.
    nonisolated static func sanitize(_ text: String) -> String {
        String(text.filter(isEmoji).prefix(WinkLimits.maxEmoji))
    }

    /// The grid. Common enough to cover most sends without opening the keyboard.
    static let common: [String] = [
        "😀","😂","🥹","😍","🥰","😎","🤩","🥳","😇","🙃",
        "😉","😌","🤔","🤨","😐","🙄","😮","😴","🤤","😭",
        "😤","😡","🥵","🥶","🤯","😱","🤝","👋","🙌","👏",
        "🙏","💪","🫶","🤞","✌️","🤙","👀","👁️","💅","🦶",
        "❤️","🧡","💛","💚","💙","💜","🖤","🤍","💔","💯",
        "🔥","✨","⭐","🌟","⚡","💥","💫","🌈","☀️","🌙",
        "🎉","🎊","🎈","🎁","🏆","🥇","⚽","🏀","🏈","⚾",
        "🍕","🍔","🌮","🍟","🍩","🍪","☕","🍺","🍷","🥂",
        "🚗","✈️","🚀","🛸","🏠","🌆","🗺️","📍","⏰","📅",
        "📱","💻","🎧","🎤","🎵","📸","💬","💤","🆗","‼️"
    ]
}
