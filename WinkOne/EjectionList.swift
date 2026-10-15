import Combine
import Foundation

/// Developer-side ejection.
///
/// WINK has no server and no accounts, so "ejecting the user" works through a
/// small public list the developer controls. Every copy of WINK downloads it:
/// anyone on it disappears from the radar, can no longer deliver a card, and
/// anything they already sent is purged from the inbox. A device that finds
/// its own ID on the list is locked out of WINK entirely.
///
/// Developer workflow (within 24 hours of a report):
///   1. The report email carries the sender's WINK ID, e.g. "uid:4F1C…".
///   2. Add that string to `ejected` in ejected.json and push.
///   3. Every copy of WINK picks it up on its next launch or return to the app.
///
/// File format:  { "ejected": ["uid:4F1C…", "uid:…"] }
@MainActor
final class EjectionList: ObservableObject {
    static let shared = EjectionList()

    static let source = URL(string: "https://raw.githubusercontent.com/codeprater/wink-safety/main/ejected.json")!

    @Published private(set) var keys: Set<String> = []

    private let cacheKey = "wink.ejected.v1"
    private var lastFetch: Date?

    private init() {
        // The last list we saw keeps working offline.
        if let cached = UserDefaults.standard.stringArray(forKey: cacheKey) {
            keys = Set(cached)
        }
    }

    /// This device's identity in the same "uid:" form reports and the list use.
    static var localKey: String { "uid:\(PeerIdentity.local)" }

    var isThisDeviceEjected: Bool { keys.contains(Self.localKey) }

    func contains(_ key: String) -> Bool {
        !key.isEmpty && keys.contains(key)
    }

    /// Cheap to call often: at most one download every 15 minutes unless forced.
    func refresh(force: Bool = false) {
        if !force, let lastFetch, Date().timeIntervalSince(lastFetch) < 15 * 60 { return }
        lastFetch = Date()

        Task {
            let request = URLRequest(
                url: Self.source,
                cachePolicy: .reloadIgnoringLocalCacheData,
                timeoutInterval: 15
            )
            // Offline, or the file is missing: keep the last list we had.
            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  let list = try? JSONDecoder().decode(ListFile.self, from: data)
            else { return }

            let next = Set(
                list.ejected
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
            guard next != keys else { return }
            keys = next
            UserDefaults.standard.set(Array(next), forKey: cacheKey)
            ModerationStore.shared.purgeEjected(next)
        }
    }

    private struct ListFile: Decodable {
        let ejected: [String]
    }
}
