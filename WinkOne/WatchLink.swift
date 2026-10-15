import Foundation
import WatchConnectivity

/// The iPhone end of the Apple Watch link.
///
/// Sends the watch a small picture of the inbox and the radar, and hands
/// anything the watch asks for to ContentView, which runs it through the same
/// filter, lock and block rules as a tap on the phone.
@MainActor
final class WatchLink: NSObject, WCSessionDelegate {
    static let shared = WatchLink()

    /// Set by ContentView. Runs on the main actor.
    var onCommand: ((WatchCommand) -> Void)?

    private var pending: WatchState?
    private var lastSent: WatchState?

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        if session.delegate == nil { session.delegate = self }
        if session.activationState != .activated { session.activate() }
    }

    func push(_ state: WatchState) {
        guard WCSession.isSupported(), state != lastSent else { return }
        let session = WCSession.default
        guard session.activationState == .activated else {
            pending = state
            return
        }
        guard session.isPaired, session.isWatchAppInstalled else { return }
        guard let data = try? JSONEncoder().encode(state) else { return }
        do {
            try session.updateApplicationContext([WatchWire.stateKey: data])
            lastSent = state
        } catch {
            pending = state
        }
    }

    private func handle(_ data: Data?) {
        guard let data,
              let command = try? JSONDecoder().decode(WatchCommand.self, from: data)
        else { return }
        if command.kind == .refresh { lastSent = nil }
        onCommand?(command)
    }

    // MARK: WCSessionDelegate (called off the main thread)

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            if let state = self.pending {
                self.pending = nil
                self.push(state)
            }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Switching to a different watch: reconnect to the new one.
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let data = message[WatchWire.commandKey] as? Data
        Task { @MainActor in self.handle(data) }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        let data = message[WatchWire.commandKey] as? Data
        replyHandler([:])
        Task { @MainActor in self.handle(data) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        let data = userInfo[WatchWire.commandKey] as? Data
        Task { @MainActor in self.handle(data) }
    }
}
