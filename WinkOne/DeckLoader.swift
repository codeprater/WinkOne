import Foundation

enum DeckLoader {
    static let atmospheres: [Atmosphere] = [
        Atmosphere(name: "Stadium", icon: "sportscourt.fill", line: "Gameday energy"),
        Atmosphere(name: "Lounge", icon: "wineglass.fill", line: "Bars & nights out"),
        Atmosphere(name: "Daily Grind", icon: "cup.and.saucer.fill", line: "Cafe, campus, work"),
        Atmosphere(name: "Gen-Z", icon: "bolt.fill", line: "Slang. Unmuted."),
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
            WinkDeck(name: "Verdicts", atmosphere: "Gen-Z", messages: genZVerdicts)
        ]
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
        "One Pride."
    ], pack: "Gameday", atmosphere: "Stadium", ink: .field)

    private static let culture = cards([
        "WHAT UP DOE?",
        "We Outside.",
        "Valid.",
        "It's a Movie.",
        "Where the after at?"
    ], pack: "Culture", atmosphere: "Stadium", ink: .gold)

    private static let gentleman = cards([
        "Excuse Me?",
        "Pardon Me?",
        "Interesting?",
        "This one is on me.",
        "Drip is respected."
    ], pack: "Gentleman", atmosphere: "Lounge", ink: .wine)

    private static let roast = cards([
        "Bro... seriously?",
        "Stop Playing.",
        "This is boring. I just remembered I have legs.",
        "This is trash.",
        "Wrap it up."
    ], pack: "Roast", atmosphere: "Lounge", ink: .ember)

    private static let interaction = cards([
        "Knock Knock?",
        "Who's There?",
        "The person with the raised phone."
    ], pack: "Interaction", atmosphere: "Lounge", ink: .ice)

    private static let canYou = cards([
        "Can you settle a debate?",
        "Can you AirDrop me that?",
        "Can you slide over? Plz.",
        "Can you take a photo of us?"
    ], pack: "Can You?", atmosphere: "Daily Grind", ink: .kraft)

    private static let sos = cards([
        "Do you have a charger?",
        "I'm at 1%. Please help.",
        "Is this seat taken?",
        "Do you have a pen?"
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
        "W'S IN THE CHAT!"
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
}
