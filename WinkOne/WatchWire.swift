import Foundation

// MARK: - iPhone <-> Apple Watch wire format
//
// The watch cannot use MultipeerConnectivity, so it never talks to other
// people directly. The phone does all sending, filtering and blocking; the
// watch is a remote for it. This file exists twice, once per target
// (WinkOne/ and WinkOneWatch/). Keep the two copies identical.

/// What the phone tells the watch. Deliberately small: no photos, no audio.
struct WatchState: Codable, Equatable {
    var name: String
    var discoverable: Bool
    var peers: [WatchPeer]
    var winks: [WatchWink]
}

struct WatchPeer: Codable, Equatable, Hashable, Identifiable {
    let id: String
    let name: String
    let locked: Bool
}

struct WatchWink: Codable, Equatable, Hashable, Identifiable {
    let id: UUID
    let fromName: String
    let kind: String
    let text: String
    let symbolName: String?
    let moodHex: String?
    let emoji: String?
    let zodiac: String?
    let hasPhoto: Bool
    let hasVoice: Bool
    let secret: Bool
    let date: Date
}

/// What the watch asks the phone to do.
struct WatchCommand: Codable {
    enum Kind: String, Codable {
        case send, reply, ghost, remove, report, block, refresh
    }

    var kind: Kind
    var peerID: String? = nil
    var winkID: UUID? = nil
    var text: String? = nil
    var symbolName: String? = nil
}

/// Read from WatchConnectivity's background callbacks, so these must not be
/// tied to the main actor.
enum WatchWire {
    nonisolated static let stateKey = "wink.state"
    nonisolated static let commandKey = "wink.command"
}
