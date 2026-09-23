import Foundation
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

    @Test func safetyFilterBlocksObjectionableContentAtIngress() {
        #expect(ContentFilter.check(text: "send nudes").isBlocked)
        #expect(ContentFilter.check(name: "safe person").isBlocked == false)
        #expect(ContentFilter.check(link: "https://pornhub.com/video").isBlocked)
    }

    @Test func ageGateAndAppStoreRatingAreAdultOnly() {
        #expect(WinkAgreement.minimumAge == 18)
        #expect(WinkAgreement.appStoreAgeRating == "18+")
    }

    @Test func reportDeadlineIsExactly24Hours() {
        let submitted = Date(timeIntervalSince1970: 1_000_000)
        let report = WinkReport(
            reportedName: "sender",
            reason: ReportReason.harassment.rawValue,
            details: "",
            evidence: "",
            date: submitted
        )
        #expect(report.deadline == submitted.addingTimeInterval(24 * 60 * 60))
        #expect(report.status == .open)
        #expect(!report.isResolved)
    }

    @Test @MainActor func payloadCarriesPrivateModerationAndContentIdentifiers() throws {
        let contentID = UUID()
        let payload = WinkPayload(
            text: "hello",
            pack: "WINK",
            atmosphere: "Lounge",
            ink: .gold,
            fromName: "Alias",
            senderModerationID: "install-123",
            contentID: contentID,
            kind: .wink
        )
        let roundTrip = try JSONDecoder().decode(
            WinkPayload.self,
            from: JSONEncoder().encode(payload)
        )

        #expect(roundTrip.senderModerationID == "install-123")
        #expect(roundTrip.contentID == contentID)
        #expect(ReceivedWink(payload: roundTrip).id == contentID)
    }

    @Test @MainActor func legacyPayloadsRemainDecodableWithoutModerationIdentifiers() throws {
        let legacy = """
        {"text":"hello","pack":"WINK","atmosphere":"Lounge","ink":"gold","fromName":"Alias","kind":"wink"}
        """.data(using: .utf8)!
        let payload = try JSONDecoder().decode(WinkPayload.self, from: legacy)

        #expect(payload.senderModerationID.isEmpty)
        #expect(!payload.contentID.uuidString.isEmpty)
    }

    @Test @MainActor func blockingAndDeletionUpdateLocalState() throws {
        let store = ModerationStore.shared
        let name = "test-\(UUID().uuidString)"
        let payload = WinkPayload.from(plain: "hello", fromName: name)
        store.remember(payload)
        let wink = try #require(store.received.first(where: { $0.payload == payload }))
        store.block(name)
        #expect(store.isBlocked(name))
        #expect(!store.received.contains(wink))
        store.unblock(BlockedUser(name: name, date: Date()))
        #expect(!store.isBlocked(name))
    }

    @Test @MainActor func reportCanResolveWithRemovalAndEjectionAudit() throws {
        let store = ModerationStore.shared
        let name = "report-\(UUID().uuidString)"
        let payload = WinkPayload.from(plain: "bad", fromName: name)
        store.remember(payload)
        let wink = try #require(store.received.first(where: { $0.payload == payload }))
        let report = store.report(
            name: name,
            reason: .other,
            details: "test",
            evidence: "bad",
            targetContentID: wink.id
        )
        store.resolve(report, removeAndEject: true)
        let resolved = try #require(store.reports.first(where: { $0.id == report.id }))
        #expect(resolved.status == .resolvedRemoved)
        #expect(resolved.removedAt != nil)
        #expect(resolved.ejectedAt != nil)
        #expect(store.isBlocked(name))
        #expect(!store.received.contains(wink))
        store.unblock(BlockedUser(name: name, date: Date()))
    }
}
