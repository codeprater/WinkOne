import Combine
import Foundation
import MultipeerConnectivity
import UIKit

/// One card waiting to be read, with the peer it came from.
struct IncomingWink: Identifiable, Equatable {
    let id: UUID
    let payload: WinkPayload
    let peer: WinkPeer?

    init(id: UUID = UUID(), payload: WinkPayload, peer: WinkPeer?) {
        self.id = id
        self.payload = payload
        self.peer = peer
    }
}

@MainActor
final class MultipeerManager: NSObject, ObservableObject {
    private let serviceType = "wink-msg"
    private var myPeerId: MCPeerID?
    private var serviceAdvertiser: MCNearbyServiceAdvertiser?
    private var serviceBrowser: MCNearbyServiceBrowser?
    private var session: MCSession?

    private var pending: [MCPeerID: WinkPayload] = [:]
    private var timeoutTasks: [MCPeerID: Task<Void, Never>] = [:]
    private var rediscoveryTask: Task<Void, Never>?

    /// Objects that have been stopped but not yet let go of. See `retire`.
    private var retiring: [AnyObject] = []

    /// One task owns every browser stop/start. Two of them interleaving is
    /// what tore the Bonjour browser down underneath itself.
    private var cycleTask: Task<Void, Never>?

    /// Debounces `restartAdvertising`. Tapping along the composer strip used to
    /// build and destroy an advertiser per tap.
    private var advertiseTask: Task<Void, Never>?

    /// When the session was last built, so a scene-phase wake arriving on the
    /// heels of `bootstrap` does not kick a browser that just started.
    private var lastRebuild = Date.distantPast

    @Published var availablePeers: [WinkPeer] = []

    /// Cards wait their turn instead of overwriting each other. Before this a
    /// second wink arriving mid-read silently replaced the first.
    @Published private(set) var queue: [IncomingWink] = []

    /// The card on screen right now.
    var incoming: WinkPayload? { queue.first?.payload }
    var incomingPeer: WinkPeer? { queue.first?.peer }

    /// How many are stacked up behind it.
    var waitingCount: Int { max(0, queue.count - 1) }
    @Published var isDiscoverable = true
    @Published var delivery: DeliveryState = .idle
    @Published private(set) var winkName = "Wink"
    @Published private(set) var atmosphere = "Stadium"

    let moderation = ModerationStore.shared

    private func isBlocked(_ name: String) -> Bool {
        moderation.isBlocked(name)
    }

    func bootstrap(name: String, atmosphere: String) {
        let cleanName = Self.sanitizedName(name)
        if session != nil, cleanName == winkName, self.atmosphere == atmosphere {
            return
        }
        let nameChanged = myPeerId?.displayName != cleanName
        winkName = cleanName
        self.atmosphere = atmosphere
        if session == nil || nameChanged {
            rebuildSession()
        } else {
            restartAdvertising()
        }
    }

    func setAtmosphere(_ name: String) {
        guard atmosphere != name else { return }
        atmosphere = name
        // Wait for them to settle on a composer before re-advertising. Twelve
        // taps along the strip is twelve advertisers otherwise.
        advertiseTask?.cancel()
        advertiseTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(1200))
            guard let self, !Task.isCancelled else { return }
            self.restartAdvertising()
        }
    }

    func toggleGhostMode() {
        isDiscoverable.toggle()
        if isDiscoverable {
            start()
        } else {
            stop()
        }
    }

    func isLocked(_ peer: WinkPeer) -> Bool {
        moderation.isLocked(peer.id)
    }

    /// Guideline 1.2: a mechanism for users to block abusive users.
    /// Blocking is permanent, survives relaunch, and drops the peer on both
    /// the browse side and the invitation side.
    func block(_ peer: WinkPeer) {
        moderation.block(key: peer.id, name: peer.winkName)
        availablePeers.removeAll { $0.id == peer.id }
        if incomingPeer?.id == peer.id {
            dismissIncoming()
        }
    }

    func blockCurrentSender() {
        if let peer = incomingPeer {
            block(peer)
        } else if let name = incoming?.fromName {
            moderation.block(name)
            dismissIncoming()
        }
    }

    /// Guideline 1.2: a mechanism for users to flag objectionable content.
    /// Reporting removes the content immediately and ejects the sender.
    func report(_ peer: WinkPeer?, name: String, reason: ReportReason, details: String, evidence: String) {
        moderation.report(name: name, reason: reason, details: details, evidence: evidence)
        if let peer {
            availablePeers.removeAll { $0.id == peer.id }
        }
        dismissIncoming()
    }

    func send(_ payload: WinkPayload, to peer: WinkPeer) {
        // Refuse anything that would not survive the wire cap.
        if let encoded = try? JSONEncoder().encode(payload),
           encoded.count > WinkLimits.maxWireBytes {
            delivery = .blocked("That card is too big to send. Try a shorter recording or another photo.")
            return
        }
        // Screen outgoing content before it can leave the device.
        let verdict = ContentFilter.check(payload: payload)
        if let reason = verdict.reason {
            moderation.noteFiltered()
            delivery = .blocked(reason)
            return
        }
        if payload.kind == .wink, isLocked(peer) {
            delivery = .locked(peer.winkName)
            return
        }
        guard let session else {
            delivery = .failed(peer.winkName)
            return
        }

        pending[peer.peerId] = payload
        delivery = .sending(peer.winkName)

        if session.connectedPeers.contains(peer.peerId) {
            flush(peer.peerId)
            return
        }

        serviceBrowser?.invitePeer(peer.peerId, to: session, withContext: nil, timeout: 12)
        timeoutTasks[peer.peerId]?.cancel()
        timeoutTasks[peer.peerId] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(12))
            guard let self, !Task.isCancelled else { return }
            if self.pending[peer.peerId] != nil {
                self.pending.removeValue(forKey: peer.peerId)
                self.delivery = .failed(peer.winkName)
            }
        }
    }

    /// Advances to the next waiting card rather than clearing the screen.
    func dismissIncoming() {
        if !queue.isEmpty { queue.removeFirst() }
    }

    func clearQueue() {
        queue.removeAll()
    }

    // MARK: - Teardown
    //
    // MultipeerConnectivity tears its Bonjour advertiser and browser down
    // asynchronously: stopping one schedules the cancel onto the run loop.
    // Releasing the object before that work runs leaves the callback pointing
    // at freed memory, and CoreFoundation traps:
    //
    //     _CFAssertMismatchedTypeID
    //     CFRunLoopSourceInvalidate
    //     _BrowserCancel(__CFNetServiceBrowser*)
    //     EXC_BREAKPOINT (SIGTRAP)
    //
    // That is the crash. The old code set `serviceBrowser = nil` on the line
    // after `stopBrowsingForPeers()`, which is exactly the race. So: detach the
    // delegate first (no callbacks into a half-dead manager), stop it, then
    // hold the object alive for a few seconds while MC finishes with it.

    private func retire(_ object: AnyObject?) {
        guard let object else { return }
        if let advertiser = object as? MCNearbyServiceAdvertiser {
            advertiser.delegate = nil
            advertiser.stopAdvertisingPeer()
        } else if let browser = object as? MCNearbyServiceBrowser {
            browser.delegate = nil
            browser.stopBrowsingForPeers()
        } else if let session = object as? MCSession {
            session.delegate = nil
            session.disconnect()
        }
        retiring.append(object)
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard let self else { return }
            if let index = self.retiring.firstIndex(where: { $0 === object }) {
                self.retiring.remove(at: index)
            }
        }
    }

    private func rebuildSession() {
        stop()          // retires the browser and clears it
        retire(session)
        retire(serviceAdvertiser)
        retire(serviceBrowser)
        session = nil
        serviceAdvertiser = nil
        serviceBrowser = nil
        lastRebuild = Date()

        let peerId = MCPeerID(displayName: winkName)
        myPeerId = peerId

        let newSession = MCSession(peer: peerId, securityIdentity: nil, encryptionPreference: .required)
        newSession.delegate = self
        session = newSession

        let advertiser = MCNearbyServiceAdvertiser(
            peer: peerId,
            discoveryInfo: discoveryInfo,
            serviceType: serviceType
        )
        advertiser.delegate = self
        serviceAdvertiser = advertiser

        let browser = MCNearbyServiceBrowser(peer: peerId, serviceType: serviceType)
        browser.delegate = self
        serviceBrowser = browser

        if isDiscoverable { start() }
    }

    private var discoveryInfo: [String: String] {
        ["atm": atmosphere, "nm": winkName, "uid": PeerIdentity.local]
    }

    private func restartAdvertising() {
        // A new discoveryInfo needs a new advertiser; the old one is retired,
        // not dropped. This runs on every composer change, so it was the most
        // frequently hit version of the crash.
        retire(serviceAdvertiser)
        serviceAdvertiser = nil
        guard let peerId = myPeerId else { return }
        let advertiser = MCNearbyServiceAdvertiser(
            peer: peerId,
            discoveryInfo: discoveryInfo,
            serviceType: serviceType
        )
        advertiser.delegate = self
        serviceAdvertiser = advertiser
        if isDiscoverable {
            advertiser.startAdvertisingPeer()
        }
    }

    private func start() {
        serviceAdvertiser?.startAdvertisingPeer()
        if serviceBrowser == nil, let peerId = myPeerId {
            let browser = MCNearbyServiceBrowser(peer: peerId, serviceType: serviceType)
            browser.delegate = self
            serviceBrowser = browser
        }
        serviceBrowser?.startBrowsingForPeers()
        startRediscovery()
    }

    /// Called when the app comes back to the front. iOS suspends the browser
    /// and the advertiser in the background, and neither reliably picks up
    /// where it left off — the room looks empty until something kicks them.
    /// This is the single biggest cause of "it can't see anyone".
    func wake() {
        guard isDiscoverable else { return }
        // On a cold launch `bootstrap` has just built and started everything,
        // and the scene going active arrives milliseconds later. Kicking the
        // browser again here is what made the crash reproducible on launch.
        guard Date().timeIntervalSince(lastRebuild) > 3 else { return }
        // Peers found before the app slept may no longer be here.
        availablePeers.removeAll()
        cycleBrowser(restartAdvertiser: true)
    }

    /// Refreshes discovery by building a *new* browser and retiring the old
    /// one. It never stops and restarts a live browser.
    ///
    /// Retiring the object was not enough on its own: `stopBrowsingForPeers()`
    /// followed later by `startBrowsingForPeers()` on the same instance is
    /// itself the call that trips `_BrowserCancel`, because MC reuses the
    /// underlying CFNetServiceBrowser and its run loop source across the
    /// restart. A fresh instance gets a fresh source, and the old one is only
    /// ever stopped once, on its way out.
    private func cycleBrowser(restartAdvertiser: Bool = false) {
        cycleTask?.cancel()
        cycleTask = Task { @MainActor [weak self] in
            guard let self, self.isDiscoverable, let peerId = self.myPeerId else { return }

            self.retire(self.serviceBrowser)
            self.serviceBrowser = nil

            // Let MC finish with the old one before its replacement starts
            // advertising interest in the same service type.
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled, self.isDiscoverable else { return }

            let browser = MCNearbyServiceBrowser(peer: peerId, serviceType: self.serviceType)
            browser.delegate = self
            self.serviceBrowser = browser
            browser.startBrowsingForPeers()

            if restartAdvertiser { self.restartAdvertising() }
        }
    }

    /// Going off the air. The browser is retired rather than stopped in place,
    /// for the same reason `cycleBrowser` builds a new one: a browser that has
    /// been stopped is never started again.
    private func stop() {
        rediscoveryTask?.cancel()
        rediscoveryTask = nil
        cycleTask?.cancel()
        cycleTask = nil
        advertiseTask?.cancel()
        advertiseTask = nil
        serviceAdvertiser?.stopAdvertisingPeer()
        retire(serviceBrowser)
        serviceBrowser = nil
        availablePeers.removeAll()
    }

    /// Multipeer browsers go stale on long sessions and after the app has been
    /// backgrounded — peers that are still in the room stop appearing. Cycling
    /// the browser on a slow timer brings them back without a relaunch.
    private func startRediscovery() {
        rediscoveryTask?.cancel()
        rediscoveryTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                // Sweep sooner while the radar is empty, back off once it is
                // not. Both intervals are deliberately unhurried: cycling a
                // Bonjour browser is the most fragile thing this class does.
                let empty = self?.availablePeers.isEmpty ?? true
                try? await Task.sleep(for: empty ? .seconds(15) : .seconds(45))
                guard let self, self.isDiscoverable, !Task.isCancelled else { return }
                self.cycleBrowser()
            }
        }
    }

    private func flush(_ peerID: MCPeerID) {
        timeoutTasks[peerID]?.cancel()
        timeoutTasks[peerID] = nil
        guard let payload = pending.removeValue(forKey: peerID),
              let session,
              let data = try? JSONEncoder().encode(payload)
        else { return }

        do {
            try session.send(data, toPeers: [peerID], with: .reliable)
            if payload.kind == .wink, let peer = availablePeers.first(where: { $0.peerId == peerID }) {
                moderation.lock(peer.id)
            }
            let peerName = availablePeers.first(where: { $0.peerId == peerID })?.winkName ?? peerID.displayName
            delivery = .delivered(payload.kind == .reply ? "Reply delivered" : peerName)
        } catch {
            delivery = .failed(peerID.displayName)
        }
    }

    private func unlock(peerID: MCPeerID) {
        if let peer = availablePeers.first(where: { $0.peerId == peerID }) {
            moderation.releaseLock(peer.id)
        }
        moderation.releaseLock("name:\(peerID.displayName.lowercased())")
    }

    static func sanitizedName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Wink" }
        // Last line of defence: an objectionable display name never goes on the air.
        guard !ContentFilter.check(name: trimmed).isBlocked else { return "Wink" }
        var name = trimmed
        while name.utf8.count > 63, !name.isEmpty {
            name.removeLast()
        }
        return name.isEmpty ? "Wink" : name
    }
}

extension MultipeerManager: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        Task { @MainActor in
            if isBlocked(peerID.displayName) {
                invitationHandler(false, nil)
                return
            }
            invitationHandler(true, session)
        }
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        Task { @MainActor in
            // Usually a transient radio or permission hiccup. Back off, retry once.
            guard isDiscoverable else { return }
            try? await Task.sleep(for: .seconds(2))
            guard isDiscoverable else { return }
            self.serviceAdvertiser?.startAdvertisingPeer()
        }
    }
}

extension MultipeerManager: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(
        _ browser: MCNearbyServiceBrowser,
        foundPeer peerID: MCPeerID,
        withDiscoveryInfo info: [String: String]?
    ) {
        Task { @MainActor in
            let name = info?["nm"] ?? peerID.displayName
            let uid = info?["uid"] ?? ""
            let peer = WinkPeer(
                peerId: peerID,
                winkName: name,
                atmosphere: info?["atm"] ?? "",
                uid: uid
            )
            // Identity first, so a rename cannot walk around a block.
            if moderation.isBlocked(key: peer.id) || isBlocked(name) { return }
            // A peer advertising an objectionable display name never appears.
            if ContentFilter.check(name: name).isBlocked {
                moderation.noteFiltered()
                return
            }
            if let index = availablePeers.firstIndex(where: { $0.peerId == peerID }) {
                availablePeers[index] = peer
            } else {
                availablePeers.append(peer)
            }
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        Task { @MainActor in
            guard isDiscoverable else { return }
            try? await Task.sleep(for: .seconds(2))
            guard isDiscoverable else { return }
            self.serviceBrowser?.startBrowsingForPeers()
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            availablePeers.removeAll { $0.peerId == peerID }
        }
    }
}

extension MultipeerManager: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            switch state {
            case .connected:
                flush(peerID)
            case .notConnected:
                if pending[peerID] != nil {
                    pending.removeValue(forKey: peerID)
                    timeoutTasks[peerID]?.cancel()
                    delivery = .failed(peerID.displayName)
                }
            default:
                break
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        Task { @MainActor in
            // Drop oversized frames before decoding them.
            guard data.count <= WinkLimits.maxWireBytes else {
                moderation.noteFiltered()
                return
            }
            let payload: WinkPayload
            if let decoded = try? JSONDecoder().decode(WinkPayload.self, from: data) {
                payload = decoded
            } else if let text = String(data: data, encoding: .utf8) {
                payload = .from(plain: text, fromName: peerID.displayName)
            } else {
                return
            }
            unlock(peerID: peerID)

            // A card from a newer build than this one.
            if payload.needsNewerApp {
                delivery = .blocked("Update WINK to see this card.")
                return
            }

            // Blocked senders can never reach the screen, even mid-session.
            if isBlocked(payload.fromName) || isBlocked(peerID.displayName) { return }

            // Screen incoming content before it is displayed. Anything that
            // matches the objectionable-content filter is dropped, never shown.
            if ContentFilter.check(payload: payload).isBlocked {
                moderation.noteFiltered()
                return
            }

            moderation.remember(payload)
            let peer = availablePeers.first(where: { $0.peerId == peerID })
                ?? WinkPeer(peerId: peerID, winkName: payload.fromName, atmosphere: payload.atmosphere)
            queue.append(IncomingWink(payload: payload, peer: peer))
        }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}
