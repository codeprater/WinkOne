import Foundation
import MultipeerConnectivity

// MARK: - Card

/// A single WINK card.
///
/// `id` is a stored UUID rather than a derived string (Fix 03). The old
/// content-derived id collided whenever two cards shared the same text in the
/// same pack, which broke `ForEach(id:)` identity in the deck and reply rows.
struct WinkMessage: Identifiable, Hashable, Codable {
    let id: UUID
    let text: String
    let pack: String
    let atmosphere: String
    let ink: CardInk

    var symbolName: String?
    var drawingData: Data?
    var latitude: Double?
    var longitude: Double?
    var placeName: String?

    // MARK: 2.0 composers
    var voiceData: Data?
    var voiceDuration: TimeInterval?
    var photoData: Data?
    var photoCaption: String?
    var photoSymbolName: String?
    var moodColorHex: String?
    var moodWord: String?
    var emojiSequence: String?
    var zodiacSign: String?

    /// The name printed on a Name Tag card. The photo rides in `photoData`.
    var nameTagName: String?

    /// A Genmoji, as the image data the keyboard handed us.
    var genmojiData: Data?

    /// Secret Wink modifier — the receiving card is veiled until tapped.
    var secretUntilTapped: Bool

    init(
        id: UUID = UUID(),
        text: String,
        pack: String,
        atmosphere: String,
        ink: CardInk,
        symbolName: String? = nil,
        drawingData: Data? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        placeName: String? = nil,
        voiceData: Data? = nil,
        voiceDuration: TimeInterval? = nil,
        photoData: Data? = nil,
        photoCaption: String? = nil,
        photoSymbolName: String? = nil,
        moodColorHex: String? = nil,
        moodWord: String? = nil,
        emojiSequence: String? = nil,
        zodiacSign: String? = nil,
        nameTagName: String? = nil,
        genmojiData: Data? = nil,
        secretUntilTapped: Bool = false
    ) {
        self.id = id
        self.text = text
        self.pack = pack
        self.atmosphere = atmosphere
        self.ink = ink
        self.symbolName = symbolName
        self.drawingData = drawingData
        self.latitude = latitude
        self.longitude = longitude
        self.placeName = placeName
        self.voiceData = voiceData
        self.voiceDuration = voiceDuration
        self.photoData = photoData
        self.photoCaption = photoCaption
        self.photoSymbolName = photoSymbolName
        self.moodColorHex = moodColorHex
        self.moodWord = moodWord
        self.emojiSequence = emojiSequence
        self.zodiacSign = zodiacSign
        self.nameTagName = nameTagName
        self.genmojiData = genmojiData
        self.secretUntilTapped = secretUntilTapped
    }

    var mapsURL: URL? {
        guard let latitude, let longitude else { return nil }
        var query = "https://maps.apple.com/?ll=\(latitude),\(longitude)"
        if let placeName, let encoded = placeName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            query += "&q=\(encoded)"
        }
        return URL(string: query)
    }

    var linkURL: URL? {
        guard atmosphere == "Links" else { return nil }
        return LinkPaste.normalized(text).flatMap(URL.init(string:))
    }
}

// MARK: - Supporting types

struct Atmosphere: Identifiable, Hashable {
    let name: String
    let icon: String
    let line: String
    var id: String { name }
}

struct WinkDeck: Identifiable, Hashable {
    let name: String
    let atmosphere: String
    let messages: [WinkMessage]
    var id: String { "\(atmosphere)|\(name)" }
}

struct WinkPeer: Identifiable, Hashable {
    let peerId: MCPeerID
    let winkName: String
    let atmosphere: String

    /// Stable per-install id advertised by the peer. Empty for a peer running a
    /// build that predates it — those fall back to the old name-based key.
    var uid: String = ""

    /// Identity for blocking, locking and radar placement.
    var id: String {
        uid.isEmpty ? "name:\(winkName.lowercased())" : "uid:\(uid)"
    }
}

// MARK: - Wire payload

/// What actually crosses the Multipeer session.
///
/// Every field added after v1 is decoded with `decodeIfPresent`, so a payload
/// written by build 10 still decodes here. `v` itself is absent in v1 payloads
/// and defaults to 1 (Fix 05).
struct WinkPayload: Codable, Equatable {
    enum Kind: String, Codable {
        case wink
        case reply
    }

    /// Bump when the wire format gains a field a previous build cannot render.
    static let currentVersion = 2

    var v: Int
    var text: String
    var pack: String
    var atmosphere: String
    var ink: CardInk
    var fromName: String
    var kind: Kind
    var symbolName: String?
    var drawingData: Data?
    var latitude: Double?
    var longitude: Double?
    var placeName: String?

    // MARK: 2.0
    var voiceData: Data?
    var voiceDuration: TimeInterval?
    var photoData: Data?
    var photoCaption: String?
    var photoSymbolName: String?
    var moodColorHex: String?
    var moodWord: String?
    var emojiSequence: String?
    var zodiacSign: String?
    var nameTagName: String?
    var genmojiData: Data?
    var secretUntilTapped: Bool

    init(
        v: Int = WinkPayload.currentVersion,
        text: String,
        pack: String,
        atmosphere: String,
        ink: CardInk,
        fromName: String,
        kind: Kind,
        symbolName: String? = nil,
        drawingData: Data? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        placeName: String? = nil,
        voiceData: Data? = nil,
        voiceDuration: TimeInterval? = nil,
        photoData: Data? = nil,
        photoCaption: String? = nil,
        photoSymbolName: String? = nil,
        moodColorHex: String? = nil,
        moodWord: String? = nil,
        emojiSequence: String? = nil,
        zodiacSign: String? = nil,
        nameTagName: String? = nil,
        genmojiData: Data? = nil,
        secretUntilTapped: Bool = false
    ) {
        self.v = v
        self.text = text
        self.pack = pack
        self.atmosphere = atmosphere
        self.ink = ink
        self.fromName = fromName
        self.kind = kind
        self.symbolName = symbolName
        self.drawingData = drawingData
        self.latitude = latitude
        self.longitude = longitude
        self.placeName = placeName
        self.voiceData = voiceData
        self.voiceDuration = voiceDuration
        self.photoData = photoData
        self.photoCaption = photoCaption
        self.photoSymbolName = photoSymbolName
        self.moodColorHex = moodColorHex
        self.moodWord = moodWord
        self.emojiSequence = emojiSequence
        self.zodiacSign = zodiacSign
        self.nameTagName = nameTagName
        self.genmojiData = genmojiData
        self.secretUntilTapped = secretUntilTapped
    }

    private enum CodingKeys: String, CodingKey {
        case v, text, pack, atmosphere, ink, fromName, kind
        case symbolName, drawingData, latitude, longitude, placeName
        case voiceData, voiceDuration, photoData, photoCaption, photoSymbolName
        case moodColorHex, moodWord, emojiSequence, zodiacSign, nameTagName
        case genmojiData, secretUntilTapped
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Absent means a v1 payload from build 10 or earlier.
        v = try c.decodeIfPresent(Int.self, forKey: .v) ?? 1
        text = try c.decode(String.self, forKey: .text)
        pack = try c.decode(String.self, forKey: .pack)
        atmosphere = try c.decode(String.self, forKey: .atmosphere)
        ink = try c.decode(CardInk.self, forKey: .ink)
        fromName = try c.decode(String.self, forKey: .fromName)
        kind = try c.decode(Kind.self, forKey: .kind)
        symbolName = try c.decodeIfPresent(String.self, forKey: .symbolName)
        drawingData = try c.decodeIfPresent(Data.self, forKey: .drawingData)
        latitude = try c.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try c.decodeIfPresent(Double.self, forKey: .longitude)
        placeName = try c.decodeIfPresent(String.self, forKey: .placeName)
        voiceData = try c.decodeIfPresent(Data.self, forKey: .voiceData)
        voiceDuration = try c.decodeIfPresent(TimeInterval.self, forKey: .voiceDuration)
        photoData = try c.decodeIfPresent(Data.self, forKey: .photoData)
        photoCaption = try c.decodeIfPresent(String.self, forKey: .photoCaption)
        photoSymbolName = try c.decodeIfPresent(String.self, forKey: .photoSymbolName)
        moodColorHex = try c.decodeIfPresent(String.self, forKey: .moodColorHex)
        moodWord = try c.decodeIfPresent(String.self, forKey: .moodWord)
        emojiSequence = try c.decodeIfPresent(String.self, forKey: .emojiSequence)
        zodiacSign = try c.decodeIfPresent(String.self, forKey: .zodiacSign)
        nameTagName = try c.decodeIfPresent(String.self, forKey: .nameTagName)
        genmojiData = try c.decodeIfPresent(Data.self, forKey: .genmojiData)
        secretUntilTapped = try c.decodeIfPresent(Bool.self, forKey: .secretUntilTapped) ?? false
    }

    /// True when this payload carries something only a newer build can render.
    var needsNewerApp: Bool { v > WinkPayload.currentVersion }

    var asMessage: WinkMessage {
        WinkMessage(
            text: text,
            pack: pack,
            atmosphere: atmosphere,
            ink: ink,
            symbolName: symbolName,
            drawingData: drawingData,
            latitude: latitude,
            longitude: longitude,
            placeName: placeName,
            voiceData: voiceData,
            voiceDuration: voiceDuration,
            photoData: photoData,
            photoCaption: photoCaption,
            photoSymbolName: photoSymbolName,
            moodColorHex: moodColorHex,
            moodWord: moodWord,
            emojiSequence: emojiSequence,
            zodiacSign: zodiacSign,
            nameTagName: nameTagName,
            genmojiData: genmojiData,
            secretUntilTapped: secretUntilTapped
        )
    }

    static func from(plain text: String, fromName: String) -> WinkPayload {
        WinkPayload(
            text: text,
            pack: "WINK",
            atmosphere: "Lounge",
            ink: .gold,
            fromName: fromName,
            kind: .wink
        )
    }

    var mapsURL: URL? {
        guard let latitude, let longitude else { return nil }
        return URL(string: "https://maps.apple.com/?ll=\(latitude),\(longitude)&q=\(placeName?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "WINK")")
    }
}

// MARK: - Delivery

enum DeliveryState: Equatable {
    case idle
    case sending(String)
    case delivered(String)
    case failed(String)
    case locked(String)
    /// Outgoing or incoming content stopped by the objectionable-content filter,
    /// or an incoming payload this build is too old to render.
    case blocked(String)
}
