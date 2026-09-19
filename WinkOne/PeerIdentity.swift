import Foundation

/// A stable, per-install identifier for this device.
///
/// Before this, blocks and one-shot locks were keyed on the display name — so a
/// blocked user could rename themselves and come straight back, and an innocent
/// person who picked a blocked name was silently blocked. The name is now for
/// display only; identity is this value, advertised in `discoveryInfo["uid"]`.
///
/// It is random, contains nothing about the device or the person, and is
/// regenerated if the app is deleted and reinstalled.
enum PeerIdentity {
    private static let key = "wink.peer.uid"

    static let local: String = {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let fresh = UUID().uuidString
        defaults.set(fresh, forKey: key)
        return fresh
    }()

    /// A deterministic 0..<1 value from an identifier, for laying peers out on
    /// the radar the same way every time. Not `String.hashValue` — that is not
    /// stable across launches.
    static func fraction(_ identifier: String, salt: UInt64 = 0) -> Double {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325 &+ salt
        for byte in identifier.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return Double(hash % 10_000) / 10_000.0
    }
}
