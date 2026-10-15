import Combine
import Foundation
import WatchConnectivity
import WatchKit

/// The watch end of the link. Holds the last picture the phone sent and
/// forwards taps back to it. Nothing here talks to other people directly.
@MainActor
final class WatchStore: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchStore()

    @Published private(set) var state: WatchState?
    @Published private(set) var phoneReachable = false
    /// A short line after an action, e.g. "Sent to your iPhone".
    @Published var notice: String?

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    var winks: [WatchWink] {
        (state?.winks ?? []).sorted { $0.date > $1.date }
    }

    func refresh() {
        send(WatchCommand(kind: .refresh), quiet: true)
    }

    func send(_ command: WatchCommand, quiet: Bool = false) {
        guard let data = try? JSONEncoder().encode(command) else { return }
        let session = WCSession.default
        let key = WatchWire.commandKey
        if session.activationState == .activated, session.isReachable {
            // The error handler runs on a background queue, so it is
            // @Sendable and captures only Sendable values.
            session.sendMessage([key: data], replyHandler: nil) { @Sendable _ in
                // Fall back to the queue if the live send fails.
                WCSession.default.transferUserInfo([key: data])
            }
            if !quiet { say("Sent to your iPhone") }
        } else {
            session.transferUserInfo([key: data])
            if !quiet { say("Queued. Open WINK on your iPhone.") }
        }
    }

    private func say(_ text: String) {
        notice = text
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            if self.notice == text { self.notice = nil }
        }
    }

    private func apply(_ data: Data?) {
        guard let data, let next = try? JSONDecoder().decode(WatchState.self, from: data) else { return }
        let before = Set(state?.winks.map(\.id) ?? [])
        let arrived = next.winks.contains { !before.contains($0.id) }
        let hadState = state != nil
        state = next
        if hadState, arrived {
            WKInterfaceDevice.current().play(.notification)
        }
    }

    // MARK: WCSessionDelegate (called off the main thread)

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        let data = session.receivedApplicationContext[WatchWire.stateKey] as? Data
        let reachable = session.isReachable
        Task { @MainActor in
            self.phoneReachable = reachable
            self.apply(data)
            self.refresh()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in
            self.phoneReachable = reachable
            if reachable { self.refresh() }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let data = applicationContext[WatchWire.stateKey] as? Data
        Task { @MainActor in self.apply(data) }
    }
}
