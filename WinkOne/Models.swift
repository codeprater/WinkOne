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
    var id: String { "\(peerId.displayName)#\(peerId.hash)" }
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
    var kind: Kind
    var symbolName: String? = nil
    var drawingData: Data? = nil
    var latitude: Double? = nil
    var longitude: Double? = nil
    var placeName: String? = nil

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
