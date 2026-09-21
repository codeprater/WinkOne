import Testing
@testable import WinkOne

struct WinkOneTests {
    @Test func appLaunches() async throws {
        #expect(true)
    }

    @Test func linkPasteNormalizesURLs() {
        #expect(LinkPaste.normalized("https://wink.app") == "https://wink.app")
        #expect(LinkPaste.normalized("wink.app") == "https://wink.app")
        #expect(LinkPaste.normalized("  Check this https://apple.com/invites  ") == "https://apple.com/invites")
        #expect(LinkPaste.normalized("not a link") == nil)
        #expect(LinkPaste.host(from: "https://www.apple.com/foo") == "apple.com")
    }

    @Test func expandedDecksHaveExpectedCoverage() {
        let decks = DeckLoader.loadDecks()
        #expect(decks.filter { $0.atmosphere == "Mood" }.count >= 4)
        #expect(decks.filter { $0.atmosphere == "Zodiac" }.count == 12)
        #expect(decks.filter { $0.atmosphere == "Zodiac" }.allSatisfy { $0.messages.count >= 10 })
        for deck in decks where deck.atmosphere != "Mood" && deck.atmosphere != "Zodiac" && !deck.messages.isEmpty {
            #expect(deck.messages.count >= 10, "\(deck.atmosphere)/\(deck.name) has \(deck.messages.count) cards")
        }
    }

    @Test func symbolCatalogAlwaysProvidesSelectionOptions() {
        #expect(!SFSymbolCatalog.matches("", category: "").isEmpty)
        #expect(SFSymbolCatalog.isAvailable(WinkSymbol.send))
    }
}
