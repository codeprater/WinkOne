import Foundation
import MultipeerConnectivity

struct WinkMessage: Identifiable, Hashable, Codable {
    var id: String { "\(atmosphere)|\(pack)|\(symbolName ?? "")|\(text)" }
    let text: String
    let pack: String
    let atmosphere: String
    let ink: CardInk
    var symbolName: String? = nil
    var drawingData: Data? = nil
    var latitude: Double? = nil
    var longitude: Double? = nil
    var placeName: String? = nil

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
    let moderationID: String?
    var id: String { "\(peerId.displayName)#\(peerId.hash)" }

    init(peerId: MCPeerID, winkName: String, atmosphere: String, moderationID: String? = nil) {
        self.peerId = peerId
        self.winkName = winkName
        self.atmosphere = atmosphere
        self.moderationID = moderationID
    }
}

struct WinkPayload: Codable, Equatable {
    enum Kind: String, Codable {
        case wink
        case reply
    }

    var text: String
    var pack: String
    var atmosphere: String
    var ink: CardInk
    var fromName: String
    /// Stable per-install identifier used only for local moderation and report
    /// correlation. It is not displayed or used as a public account identity.
    var senderModerationID: String = ""
    /// Stable content identifier used to correlate a report with the received
    /// card without storing or exposing the card author's real identity.
    var contentID: UUID = UUID()
    var kind: Kind
    var symbolName: String? = nil
    var drawingData: Data? = nil
    var latitude: Double? = nil
    var longitude: Double? = nil
    var placeName: String? = nil

    private enum CodingKeys: String, CodingKey {
        case text, pack, atmosphere, ink, fromName, senderModerationID, contentID
        case kind, symbolName, drawingData, latitude, longitude, placeName
    }

    init(
        text: String,
        pack: String,
        atmosphere: String,
        ink: CardInk,
        fromName: String,
        senderModerationID: String = "",
        contentID: UUID = UUID(),
        kind: Kind,
        symbolName: String? = nil,
        drawingData: Data? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        placeName: String? = nil
    ) {
        self.text = text
        self.pack = pack
        self.atmosphere = atmosphere
        self.ink = ink
        self.fromName = fromName
        self.senderModerationID = senderModerationID
        self.contentID = contentID
        self.kind = kind
        self.symbolName = symbolName
        self.drawingData = drawingData
        self.latitude = latitude
        self.longitude = longitude
        self.placeName = placeName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            text: try container.decode(String.self, forKey: .text),
            pack: try container.decode(String.self, forKey: .pack),
            atmosphere: try container.decode(String.self, forKey: .atmosphere),
            ink: try container.decode(CardInk.self, forKey: .ink),
            fromName: try container.decode(String.self, forKey: .fromName),
            senderModerationID: try container.decodeIfPresent(String.self, forKey: .senderModerationID) ?? "",
            contentID: try container.decodeIfPresent(UUID.self, forKey: .contentID) ?? UUID(),
            kind: try container.decode(Kind.self, forKey: .kind),
            symbolName: try container.decodeIfPresent(String.self, forKey: .symbolName),
            drawingData: try container.decodeIfPresent(Data.self, forKey: .drawingData),
            latitude: try container.decodeIfPresent(Double.self, forKey: .latitude),
            longitude: try container.decodeIfPresent(Double.self, forKey: .longitude),
            placeName: try container.decodeIfPresent(String.self, forKey: .placeName)
        )
    }

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
            placeName: placeName
        )
    }

    var effectiveSenderModerationID: String {
        senderModerationID.isEmpty ? fromName.lowercased() : senderModerationID
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

enum DeliveryState: Equatable {
    case idle
    case sending(String)
    case delivered(String)
    case failed(String)
    case locked(String)
    /// Outgoing or incoming content stopped by the objectionable-content filter.
    case blocked(String)
}
