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
}
