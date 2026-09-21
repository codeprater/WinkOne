import Foundation

enum DeckLoader {
    static let atmospheres: [Atmosphere] = [
        Atmosphere(name: "Stadium", icon: "sportscourt.fill", line: "Gameday energy"),
        Atmosphere(name: "Lounge", icon: "wineglass.fill", line: "Bars & nights out"),
        Atmosphere(name: "Daily Grind", icon: "cup.and.saucer.fill", line: "Cafe, campus, work"),
        Atmosphere(name: "Gen-Z", icon: "bolt.fill", line: "Slang. Unmuted."),
        Atmosphere(name: "Mood", icon: "paintpalette.fill", line: "Pick a color for the feeling"),
        Atmosphere(name: "Zodiac", icon: "sparkles", line: "Twelve signs, twelve vibes"),
        Atmosphere(name: "Symbols", icon: "square.grid.2x2.fill", line: "Caption any SF Symbol"),
        Atmosphere(name: "Handwritten", icon: "pencil.and.scribble", line: "Pencil or finger"),
        Atmosphere(name: "Links", icon: "link", line: "Paste a link and send")
    ]

    static func loadDecks() -> [WinkDeck] {
        [
            WinkDeck(name: "Gameday", atmosphere: "Stadium", messages: gameday),
            WinkDeck(name: "Culture", atmosphere: "Stadium", messages: culture),
            WinkDeck(name: "Gentleman", atmosphere: "Lounge", messages: gentleman),
            WinkDeck(name: "Roast", atmosphere: "Lounge", messages: roast),
            WinkDeck(name: "Interaction", atmosphere: "Lounge", messages: interaction),
            WinkDeck(name: "Can You?", atmosphere: "Daily Grind", messages: canYou),
            WinkDeck(name: "S.O.S.", atmosphere: "Daily Grind", messages: sos),
            WinkDeck(name: "Calls", atmosphere: "Gen-Z", messages: genZCalls),
            WinkDeck(name: "Verdicts", atmosphere: "Gen-Z", messages: genZVerdicts),
            WinkDeck(name: "Joy", atmosphere: "Mood", messages: mood("Joy", ink: .coral)),
            WinkDeck(name: "Calm", atmosphere: "Mood", messages: mood("Calm", ink: .mint)),
            WinkDeck(name: "Energy", atmosphere: "Mood", messages: mood("Energy", ink: .tangerine)),
            WinkDeck(name: "Dreamy", atmosphere: "Mood", messages: mood("Dreamy", ink: .lavender))
        ]
        + zodiacDecks
    }

    static func pack(_ name: String, in atmosphere: String) -> WinkDeck? {
        loadDecks().first { $0.name == name && $0.atmosphere == atmosphere }
    }

    private static func cards(_ texts: [String], pack: String, atmosphere: String, ink: CardInk) -> [WinkMessage] {
        texts.map { WinkMessage(text: $0, pack: pack, atmosphere: atmosphere, ink: ink) }
    }

    private static let gameday = cards([
        "Who is the GOAT?",
        "We winning this?",
        "Ref is blind.",
        "Make some noise!",
        "Bad Call.",
        "One Pride.", "Defense wins.", "Run it back.", "Halftime?", "Let's go!"
    ], pack: "Gameday", atmosphere: "Stadium", ink: .field)

    private static let culture = cards([
        "WHAT UP DOE?",
        "We Outside.",
        "Valid.",
        "It's a Movie.",
        "Where the after at?", "Big city energy.", "You outside tonight?", "Main character mode.", "Say less."
    ], pack: "Culture", atmosphere: "Stadium", ink: .gold)

    private static let gentleman = cards([
        "Excuse Me?",
        "Pardon Me?",
        "Interesting?",
        "This one is on me.",
        "Drip is respected.", "Your move.", "Allow me.", "Class act.", "Cheers to that."
    ], pack: "Gentleman", atmosphere: "Lounge", ink: .wine)

    private static let roast = cards([
        "Bro... seriously?",
        "Stop Playing.",
        "This is boring. I just remembered I have legs.",
        "This is trash.",
        "Wrap it up.", "That was a choice.", "Please be serious.", "I have notes.", "Respectfully, no."
    ], pack: "Roast", atmosphere: "Lounge", ink: .ember)

    private static let interaction = cards([
        "Knock Knock?",
        "Who's There?",
        "The person with the raised phone.", "Your turn to choose.", "Guess what?", "Look over here.",         "We should talk.", "You first.", "Plot twist.", "Tell me everything."
    ], pack: "Interaction", atmosphere: "Lounge", ink: .ice)

    private static let canYou = cards([
        "Can you settle a debate?",
        "Can you AirDrop me that?",
        "Can you slide over? Plz.",
        "Can you take a photo of us?", "Can you hold my spot?", "Can you pick a playlist?", "Can you settle this?",         "Can you save me a seat?", "Can you send the details?"
    ], pack: "Can You?", atmosphere: "Daily Grind", ink: .kraft)

    private static let sos = cards([
        "Do you have a charger?",
        "I'm at 1%. Please help.",
        "Is this seat taken?",
        "Do you have a pen?", "Do you have a minute?", "Do you know the Wi-Fi?", "Can I borrow that?", "I need a tiny favor.", "Emergency snack?"
    ], pack: "S.O.S.", atmosphere: "Daily Grind", ink: .ember)

    private static let genZCalls = cards([
        "AYO!",
        "YURR!",
        "ONNAT!",
        "BRO!",
        "CRASH-OUT!",
        "SUIIIIIII!!!",
        "LOCK-IN!",
        "WHAT UP DOE?",
        "W'S IN THE CHAT!",
        "WE UP!"
    ], pack: "Calls", atmosphere: "Gen-Z", ink: .volt)

    private static let genZVerdicts = cards([
        "FIRE",
        "NO CAP",
        "VALID",
        "RIZZ",
        "DRIP",
        "AURA",
        "ATE",
        "MID",
        "SUS",
        "DELULU",
        "CHEUGY",
        "GUCCI",
        "LOWKEY",
        "HITS DIFF",
        "COOK",
        "SAY LESS",
        "IT'S GIVING",
        "ONG",
        "BET"
    ], pack: "Verdicts", atmosphere: "Gen-Z", ink: .ink)

    private static func mood(_ name: String, ink: CardInk) -> [WinkMessage] {
        cards([
            "\(name) check.",
            "This is a \(name.lowercased()) kind of day.",
            "Sending \(name.lowercased()) energy.",
            "Your vibe is immaculate.",
            "Keep that feeling close.",
            "A little \(name.lowercased()) goes a long way.",
            "Mood unlocked.",
            "No notes. Just vibes.",
            "Pause and enjoy this.",
            "Color me \(name.lowercased())."
        ], pack: name, atmosphere: "Mood", ink: ink)
    }

    private static let zodiacNames = [
        ("Aries", "Bold"), ("Taurus", "Grounded"), ("Gemini", "Curious"),
        ("Cancer", "Caring"), ("Leo", "Radiant"), ("Virgo", "Thoughtful"),
        ("Libra", "Balanced"), ("Scorpio", "Magnetic"), ("Sagittarius", "Adventurous"),
        ("Capricorn", "Focused"), ("Aquarius", "Original"), ("Pisces", "Imaginative")
    ]

    private static var zodiacDecks: [WinkDeck] {
        zodiacNames.map { sign, trait in
            WinkDeck(
                name: sign,
                atmosphere: "Zodiac",
                messages: cards([
                    "\(sign) energy.",
                    "Classic \(sign).",
                    "Your \(trait.lowercased()) side is showing.",
                    "The stars said go for it.",
                    "You make this look easy.",
                    "Big \(trait.lowercased()) mood.",
                    "Trust your constellation.",
                    "A cosmic yes from me.",
                    "Your sign understood the assignment.",
                    "Stay true to your \(trait.lowercased()) heart."
                ], pack: sign, atmosphere: "Zodiac", ink: zodiacInk(sign))
            )
        }
    }

    private static func zodiacInk(_ sign: String) -> CardInk {
        switch sign {
        case "Aries": .coral
        case "Taurus": .field
        case "Gemini": .sky
        case "Cancer": .ice
        case "Leo": .gold
        case "Virgo": .mint
        case "Libra": .lavender
        case "Scorpio": .plum
        case "Sagittarius": .tangerine
        case "Capricorn": .ink
        case "Aquarius": .ocean
        default: .rose
        }
    }
}
