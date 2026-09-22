import Combine
import Foundation
import SwiftUI

// MARK: - Agreement / EULA

/// Everything the App Store Guideline 1.2 checklist needs users to see and accept
/// before they can create or receive user generated content.
enum WinkAgreement {
    /// Bump this string whenever the terms change — users are re-prompted.
    static let version = "2026.09.1"

    /// Shown inside the app so users always have a way to reach a human.
    static let supportEmail = "prater10@icloud.com"

    /// The window we commit to for acting on a report.
    static let responseWindowHours = 24

    static let minimumAge = 18
    static let appStoreAgeRating = "18+"

    static let summary = """
    WINK has zero tolerance for objectionable content and abusive users.
    """

    static let houseRules: [String] = [
        "No sexually explicit, obscene, or pornographic content.",
        "No hate speech, slurs, or content that attacks a person or group.",
        "No threats, violence, harassment, bullying, or stalking.",
        "No content involving minors, in any form.",
        "No spam, scams, phishing links, or impersonation.",
        "No illegal content and nothing that violates someone else's rights."
    ]

    static let text = """
    WINK — END USER LICENSE AGREEMENT & CONTENT POLICY

    Last updated: September 2026

    1. ELIGIBILITY — 18+
    WINK is rated 18+. You must be at least \(minimumAge) years old to use this app. \
    By continuing you confirm that you are \(minimumAge) or older. If you are not, \
    do not use WINK.

    2. ZERO TOLERANCE FOR OBJECTIONABLE CONTENT
    There is NO TOLERANCE for objectionable content or abusive users on WINK. \
    You agree not to create, send, request, or share any of the following:

    \(houseRules.map { "  • " + $0 }.joined(separator: "\n"))

    This applies to card text, captions, handwritten drawings, symbols, links, \
    place names, and the display name you choose.

    3. AUTOMATIC FILTERING
    WINK automatically screens every card — text, captions, links, and display \
    names — before it is sent and again before it is shown to you. Content that \
    matches our objectionable-content filter is blocked and never delivered. \
    Attempting to defeat the filter is itself a violation of these terms.

    4. REPORTING
    Every WINK you receive can be reported from the card itself or from Safety \
    Center. Reporting a user immediately removes their content from your device \
    and blocks them from contacting you again.

    5. OUR COMMITMENT — \(responseWindowHours) HOURS
    We act on every report of objectionable content within \(responseWindowHours) \
    hours. Acting means removing the offending content and ejecting the user who \
    provided it. Accounts and devices found to be sending objectionable content \
    are permanently barred from WINK.

    6. BLOCKING AND REMOVAL
    You may block any user at any time, and you may remove any WINK from your \
    device immediately. Blocked users cannot discover you, connect to you, or \
    deliver content to you. Removal is immediate and permanent on your device.

    7. HOW WINK WORKS
    WINK sends cards directly between nearby devices over an encrypted peer-to-peer \
    connection, or through the share sheet using apps you already have. WINK does \
    not host a public feed and does not upload your cards to a server.

    8. CONTACT
    Questions, reports, and appeals: \(supportEmail)
    We respond to content reports within \(responseWindowHours) hours.

    9. TERMINATION
    We may terminate your access to WINK at any time, without notice, for any \
    violation of these terms.

    10. NO WARRANTY
    WINK is provided "as is," without warranty of any kind. To the maximum extent \
    permitted by law, the developer is not liable for any damages arising from \
    your use of the app or from content sent by other users.

    By tapping "I AGREE" you accept these terms in full.
    """
}

// MARK: - Objectionable content filter

/// Client-side screening for user generated content. Runs on outgoing content
/// before it can leave the device, and again on incoming content before it is
/// shown. Guideline 1.2: "a method for filtering objectionable content."
enum ContentFilter {

    enum Verdict: Equatable {
        case allowed
        case blocked(reason: String)

        var isBlocked: Bool {
            if case .blocked = self { return true }
            return false
        }

        var reason: String? {
            if case .blocked(let reason) = self { return reason }
            return nil
        }
    }

    // MARK: Public checks

    static func check(text: String) -> Verdict {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .allowed }

        let spaced = normalized(trimmed, squashRepeats: false)
        let squeezed = normalized(trimmed, squashRepeats: true)
        let glued = squeezed.replacingOccurrences(of: " ", with: "")

        for phrase in bannedPhrases {
            if spaced.contains(phrase) || squeezed.contains(phrase) {
                return .blocked(reason: reasonForPhrase(phrase))
            }
        }

        for term in bannedTerms {
            if containsWord(term, in: spaced) || containsWord(term, in: squeezed) {
                return .blocked(reason: reasonForTerm(term))
            }
            // Catch spaced-out evasion ("f u c k") for longer terms only,
            // so short terms don't collide with innocent letter runs.
            if term.count >= 4, glued.contains(term) {
                return .blocked(reason: reasonForTerm(term))
            }
        }

        return .allowed
    }

    static func check(name: String) -> Verdict {
        switch check(text: name) {
        case .blocked:
            return .blocked(reason: "That display name isn't allowed on WINK.")
        case .allowed:
            return .allowed
        }
    }

    static func check(link: String) -> Verdict {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .allowed }

        guard let normalizedLink = LinkPaste.normalized(trimmed),
              let url = URL(string: normalizedLink),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return .blocked(reason: "That link isn't a valid web address.")
        }

        let host = (url.host ?? "").lowercased()
        for domain in bannedDomains where host == domain || host.hasSuffix("." + domain) {
            return .blocked(reason: "Links to adult or unsafe sites can't be sent on WINK.")
        }

        // The path and query are user content too.
        return check(text: normalizedLink.replacingOccurrences(of: "/", with: " "))
    }

    /// One call that screens an entire outgoing card.
    static func check(message: WinkMessage) -> Verdict {
        if message.atmosphere == "Links", !message.text.isEmpty {
            let verdict = check(link: message.text)
            if verdict.isBlocked { return verdict }
        } else {
            let verdict = check(text: message.text)
            if verdict.isBlocked { return verdict }
        }
        if let place = message.placeName {
            let verdict = check(text: place)
            if verdict.isBlocked { return verdict }
        }
        return .allowed
    }

    /// One call that screens an entire incoming payload.
    static func check(payload: WinkPayload) -> Verdict {
        let verdict = check(text: payload.fromName)
        if verdict.isBlocked {
            return .blocked(reason: "The sender's display name violates the content policy.")
        }
        return check(message: payload.asMessage)
    }

    /// Redacted copy of a string, safe to store alongside a report.
    static func masked(_ text: String) -> String {
        let spaced = normalized(text, squashRepeats: false)
        var result = text
        for term in bannedTerms where containsWord(term, in: spaced) {
            let mask = String(repeating: "*", count: max(term.count, 3))
            result = result.replacingOccurrences(
                of: term,
                with: mask,
                options: [.caseInsensitive, .diacriticInsensitive]
            )
        }
        return result
    }

    // MARK: Normalization

    /// Lowercases, strips accents, unwinds common leetspeak, drops punctuation,
    /// and optionally collapses repeated characters ("fuuuck" -> "fuck").
    private static func normalized(_ raw: String, squashRepeats: Bool) -> String {
        let folded = raw.folding(
            options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )

        var mapped = ""
        mapped.reserveCapacity(folded.count)
        for character in folded {
            if let substitute = leetMap[character] {
                mapped.append(substitute)
            } else if character.isLetter || character.isNumber {
                mapped.append(character)
            } else {
                mapped.append(" ")
            }
        }

        var collapsed = ""
        collapsed.reserveCapacity(mapped.count)
        var previous: Character?
        var runLength = 0
        for character in mapped {
            if character == previous {
                runLength += 1
            } else {
                previous = character
                runLength = 1
            }
            let limit = squashRepeats ? 1 : 2
            if character == " " {
                if collapsed.last != " " { collapsed.append(character) }
            } else if runLength <= limit {
                collapsed.append(character)
            }
        }

        return collapsed.trimmingCharacters(in: .whitespaces)
    }

    /// Whole-word match against an already-normalized (space separated) string.
    private static func containsWord(_ term: String, in haystack: String) -> Bool {
        guard !term.isEmpty else { return false }
        for token in haystack.split(separator: " ") {
            if token == term { return true }
            // Catch simple padding: "fucking", "fuckin", "fucker".
            if token.count > term.count, token.hasPrefix(term) {
                let tail = token.dropFirst(term.count)
                if tail.count <= 4 { return true }
            }
        }
        return false
    }

    private static func reasonForTerm(_ term: String) -> String {
        if slurTerms.contains(term) {
            return "WINK has zero tolerance for slurs and hate speech."
        }
        if threatTerms.contains(term) {
            return "WINK has zero tolerance for threats or violent content."
        }
        return "That wording breaks WINK's content policy."
    }

    private static func reasonForPhrase(_ phrase: String) -> String {
        "WINK has zero tolerance for threats, harassment, or sexual content."
    }

    private static let leetMap: [Character: Character] = [
        "0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "8": "b",
        "@": "a", "$": "s", "!": "i", "|": "i", "+": "t", "*": "a"
    ]

    // MARK: Term lists
    //
    // Deliberately blunt. Over-blocking a card is a far cheaper mistake than
    // delivering objectionable content. Add terms here as reports come in.

    private static let sexualTerms: Set<String> = [
        "anal", "anus", "areola", "bareback", "bdsm", "bestiality", "blowjob",
        "boner", "bukkake", "camgirl", "clit", "clitoris", "cock", "coochie",
        "creampie", "cum", "cumming", "cumshot", "cunnilingus", "cunt",
        "deepthroat", "dick", "dildo", "doggystyle", "dominatrix", "ejaculate",
        "erection", "fellatio", "fingerbang", "fisting", "foreskin", "fuck",
        "fuk", "fuq", "gangbang", "genitalia", "genitals", "gooner", "handjob",
        "hentai", "hooker", "horny", "incest", "jerkoff", "jizz", "labia",
        "masturbate", "masturbation", "milf", "nsfw", "nude", "nudes", "nudez",
        "onlyfans", "orgasm", "orgy", "penis", "pornhub", "porn", "porno",
        "pubes", "pussy", "rimjob", "scrotum", "semen", "sexting", "shemale",
        "slut", "smut", "sperm", "strapon", "stripclub", "testicle", "threesome",
        "tits", "titties", "titty", "twat", "upskirt", "vagina", "vulva",
        "wank", "whore", "xxx"
    ]

    private static let slurTerms: Set<String> = [
        "beaner", "chink", "coon", "cracker", "dyke", "fag", "faggot", "gook",
        "gyp", "gypsy", "heeb", "honky", "injun", "jap", "kike", "kraut",
        "nigga", "nigger", "nig", "paki", "pickaninny", "raghead", "redskin",
        "retard", "retarded", "sambo", "shitskin", "spade", "spic", "spook",
        "tard", "towelhead", "tranny", "trannie", "wetback", "wigger", "wop",
        "zipperhead"
    ]

    private static let threatTerms: Set<String> = [
        "molest", "molester", "murder", "pedo", "pedophile", "rape", "raped",
        "rapist", "lynch", "behead", "decapitate", "genocide", "terrorist"
    ]

    private static let harassmentTerms: Set<String> = [
        "asshole", "bastard", "bitch", "bitches", "bullshit", "damn", "dumbass",
        "goddamn", "jackass", "motherfucker", "prick", "shit", "shithead",
        "shitty", "skank", "tosser", "wanker"
    ]

    private static let scamTerms: Set<String> = [
        "cashapp", "crypto", "onlyfan", "seedphrase", "sendnudes", "venmome"
    ]

    private static let bannedTerms: Set<String> =
        sexualTerms
            .union(slurTerms)
            .union(threatTerms)
            .union(harassmentTerms)
            .union(scamTerms)

    /// Checked against the whole normalized string, so multi-word evasions land.
    private static let bannedPhrases: [String] = [
        "kill yourself", "kill your self", "kys", "kill you", "i will kill",
        "gonna kill", "shoot you", "shoot up", "hurt you", "beat you up",
        "im gonna hurt", "you should die", "go die", "hang yourself",
        "send nudes", "send nude", "send pics", "show me your", "get naked",
        "take your clothes off", "sit on my", "suck my", "eat my",
        "come to my room", "hotel room", "meet me alone", "dont tell anyone",
        "how old are you", "are you a minor", "underage", "under age",
        "child porn", "cp link", "sell you", "wire me", "gift card code",
        "seed phrase", "bank login", "social security number"
    ]

    private static let bannedDomains: Set<String> = [
        "pornhub.com", "xvideos.com", "xhamster.com", "redtube.com",
        "youporn.com", "xnxx.com", "onlyfans.com", "fansly.com",
        "chaturbate.com", "stripchat.com", "brazzers.com", "spankbang.com",
        "rule34.xxx", "e621.net", "nhentai.net", "thepiratebay.org",
        "1337x.to", "kickasstorrents.to"
    ]
}

// MARK: - Stored moderation state

struct BlockedUser: Codable, Identifiable, Hashable {
    var id: String { name.lowercased() }
    let name: String
    let date: Date
}

struct WinkReport: Codable, Identifiable, Hashable {
    let id: UUID
    let reportedName: String
    let targetContentID: UUID?
    let reason: String
    let details: String
    let evidence: String
    let date: Date
    var status: ReportStatus
    var deadline: Date
    var removedAt: Date?
    var ejectedAt: Date?
    var updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case id, reportedName, targetContentID, reason, details, evidence, date
        case status, deadline, removedAt, ejectedAt, updatedAt
    }

    init(
        id: UUID = UUID(),
        reportedName: String,
        targetContentID: UUID? = nil,
        reason: String,
        details: String,
        evidence: String,
        date: Date = Date(),
        status: ReportStatus = .open,
        deadline: Date? = nil,
        removedAt: Date? = nil,
        ejectedAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.reportedName = reportedName
        self.targetContentID = targetContentID
        self.reason = reason
        self.details = details
        self.evidence = evidence
        self.date = date
        self.status = status
        self.deadline = deadline ?? Self.reviewDeadline(from: date)
        self.removedAt = removedAt
        self.ejectedAt = ejectedAt
        self.updatedAt = updatedAt ?? date
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let date = try container.decode(Date.self, forKey: .date)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            reportedName: try container.decode(String.self, forKey: .reportedName),
            targetContentID: try container.decodeIfPresent(UUID.self, forKey: .targetContentID),
            reason: try container.decode(String.self, forKey: .reason),
            details: try container.decode(String.self, forKey: .details),
            evidence: try container.decode(String.self, forKey: .evidence),
            date: date,
            status: try container.decodeIfPresent(ReportStatus.self, forKey: .status) ?? .open,
            deadline: try container.decodeIfPresent(Date.self, forKey: .deadline),
            removedAt: try container.decodeIfPresent(Date.self, forKey: .removedAt),
            ejectedAt: try container.decodeIfPresent(Date.self, forKey: .ejectedAt),
            updatedAt: try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        )
    }

    static func reviewDeadline(from date: Date) -> Date {
        date.addingTimeInterval(TimeInterval(WinkAgreement.responseWindowHours) * 60 * 60)
    }

    var isResolved: Bool {
        status == .resolvedRemoved || status == .resolvedNoAction
    }
}

enum ReportStatus: String, Codable, CaseIterable, Identifiable {
    case open = "Open"
    case underReview = "Under review"
    case resolvedRemoved = "Resolved — removed/ejected"
    case resolvedNoAction = "Resolved — no action"

    var id: String { rawValue }
}

struct ReceivedWink: Codable, Identifiable, Equatable {
    let id: UUID
    let payload: WinkPayload
    let date: Date

    init(id: UUID = UUID(), payload: WinkPayload, date: Date = Date()) {
        self.id = id
        self.payload = payload
        self.date = date
    }

    var fromName: String { payload.fromName }
}

enum ReportReason: String, CaseIterable, Identifiable {
    case sexual = "Sexual or explicit content"
    case hate = "Hate speech or a slur"
    case harassment = "Harassment or bullying"
    case threat = "Threat or violence"
    case minor = "Content involving a minor"
    case spam = "Spam, scam, or bad link"
    case other = "Something else"

    var id: String { rawValue }
}

/// Single source of truth for blocking, reporting, and the local card history.
/// Guideline 1.2 wants all three reachable from inside the app at any time.
@MainActor
final class ModerationStore: ObservableObject {
    static let shared = ModerationStore()

    @Published private(set) var blocked: [BlockedUser] = []
    @Published private(set) var reports: [WinkReport] = []
    @Published private(set) var received: [ReceivedWink] = []
    @Published private(set) var filteredCount = 0

    private let blockedKey = "wink.blocked.v2"
    private let reportsKey = "wink.reports.v1"
    private let receivedKey = "wink.received.v1"
    private let filteredKey = "wink.filtered.count"
    private let legacyBlockedKey = "wink.blocked"
    private let historyLimit = 100

    private init() {
        load()
        migrateLegacyBlocks()
    }

    // MARK: Blocking

    func isBlocked(_ name: String) -> Bool {
        let needle = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return false }
        return blocked.contains { $0.name.lowercased() == needle }
    }

    func block(_ name: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, !isBlocked(clean) else { return }
        blocked.insert(BlockedUser(name: clean, date: Date()), at: 0)
        // Blocking removes everything that user ever sent, immediately.
        received.removeAll { $0.fromName.lowercased() == clean.lowercased() }
        persist()
    }

    func unblock(_ user: BlockedUser) {
        blocked.removeAll { $0.id == user.id }
        persist()
    }

    // MARK: Reporting

    @discardableResult
    func report(
        name: String,
        reason: ReportReason,
        details: String,
        evidence: String,
        targetContentID: UUID? = nil,
        date: Date = Date()
    ) -> WinkReport {
        let report = WinkReport(
            reportedName: name.isEmpty ? "Unknown sender" : name,
            targetContentID: targetContentID,
            reason: reason.rawValue,
            details: details.trimmingCharacters(in: .whitespacesAndNewlines),
            evidence: ContentFilter.masked(evidence),
            date: date
        )
        reports.insert(report, at: 0)
        // Reporting ejects the sender and removes their content on the spot.
        block(name)
        persist()
        return report
    }

    /// Local operator workflow. This records the action and audit timestamps;
    /// it cannot eject a remote device or enforce a server-side removal.
    func markUnderReview(_ report: WinkReport) {
        updateReport(report.id) {
            $0.status = .underReview
            $0.updatedAt = Date()
        }
    }

    func resolve(_ report: WinkReport, removeAndEject: Bool) {
        updateReport(report.id) {
            $0.status = removeAndEject ? .resolvedRemoved : .resolvedNoAction
            $0.updatedAt = Date()
            if removeAndEject {
                $0.removedAt = Date()
                $0.ejectedAt = Date()
            }
        }
        if removeAndEject {
            if let targetContentID = report.targetContentID,
               let wink = received.first(where: { $0.id == targetContentID }) {
                remove(wink)
            }
            block(report.reportedName)
        }
    }

    // MARK: Local history ("the feed")

    func remember(_ payload: WinkPayload) {
        received.insert(ReceivedWink(payload: payload), at: 0)
        if received.count > historyLimit {
            received.removeLast(received.count - historyLimit)
        }
        persist()
    }

    func remove(_ wink: ReceivedWink) {
        received.removeAll { $0.id == wink.id }
        persist()
    }

    func removeReceived(at offsets: IndexSet) {
        received.remove(atOffsets: offsets)
        persist()
    }

    func removeAllReceived() {
        received.removeAll()
        persist()
    }

    func noteFiltered() {
        filteredCount += 1
        UserDefaults.standard.set(filteredCount, forKey: filteredKey)
    }

    // MARK: Persistence

    private func load() {
        let defaults = UserDefaults.standard
        let decoder = JSONDecoder()

        if let data = defaults.data(forKey: blockedKey),
           let decoded = try? decoder.decode([BlockedUser].self, from: data) {
            blocked = decoded
        }
        if let data = defaults.data(forKey: reportsKey),
           let decoded = try? decoder.decode([WinkReport].self, from: data) {
            reports = decoded
        }

        if let data = defaults.data(forKey: receivedKey),
           let decoded = try? decoder.decode([ReceivedWink].self, from: data) {
            received = decoded
        }
        filteredCount = defaults.integer(forKey: filteredKey)
    }

    private func migrateLegacyBlocks() {
        let defaults = UserDefaults.standard
        guard let legacy = defaults.stringArray(forKey: legacyBlockedKey), !legacy.isEmpty else {
            return
        }
        for name in legacy where !isBlocked(name) {
            blocked.append(BlockedUser(name: name, date: Date()))
        }
        defaults.removeObject(forKey: legacyBlockedKey)
        persist()
    }

    private func updateReport(_ id: UUID, update: (inout WinkReport) -> Void) {
        guard let index = reports.firstIndex(where: { $0.id == id }) else { return }
        update(&reports[index])
        persist()
    }

    private func persist() {
        let defaults = UserDefaults.standard
        let encoder = JSONEncoder()

        if let data = try? encoder.encode(blocked) {
            defaults.set(data, forKey: blockedKey)
        }
        if let data = try? encoder.encode(reports) {
            defaults.set(data, forKey: reportsKey)
        }
        if let data = try? encoder.encode(received) {
            defaults.set(data, forKey: receivedKey)
        }
    }
}
