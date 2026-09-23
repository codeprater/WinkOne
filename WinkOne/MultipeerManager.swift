import Combine
import Foundation
import MultipeerConnectivity
import UIKit

@MainActor
final class MultipeerManager: NSObject, ObservableObject {
    private let serviceType = "wink-msg"
    private var myPeerId: MCPeerID?
    private var serviceAdvertiser: MCNearbyServiceAdvertiser?
    private var serviceBrowser: MCNearbyServiceBrowser?
    private var session: MCSession?

    private var pending: [MCPeerID: WinkPayload] = [:]
    private var locks: Set<String> = []
    private var timeoutTasks: [MCPeerID: Task<Void, Never>] = [:]

    @Published var availablePeers: [WinkPeer] = []
    @Published var incoming: WinkPayload?
    @Published var incomingPeer: WinkPeer?
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
        restartAdvertising()
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
        locks.contains(peer.id)
    }

    /// Guideline 1.2: a mechanism for users to block abusive users.
    /// Blocking is permanent, survives relaunch, and drops the peer on both
    /// the browse side and the invitation side.
    func block(_ peer: WinkPeer) {
        moderation.block(peer.winkName, moderationID: peer.moderationID)
        moderation.block(peer.peerId.displayName, moderationID: peer.moderationID)
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

    func dismissIncoming() {
        incoming = nil
        incomingPeer = nil
    }

    private func rebuildSession() {
        stop()
        session?.disconnect()
        session = nil
        serviceAdvertiser = nil
        serviceBrowser = nil

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
        ["atm": atmosphere, "nm": winkName, "mid": moderation.localModerationID]
    }

    private func restartAdvertising() {
        serviceAdvertiser?.stopAdvertisingPeer()
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
        serviceBrowser?.startBrowsingForPeers()
    }

    private func stop() {
        serviceAdvertiser?.stopAdvertisingPeer()
        serviceBrowser?.stopBrowsingForPeers()
        availablePeers.removeAll()
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
            if payload.kind == .wink {
                if let peer = availablePeers.first(where: { $0.peerId == peerID }) {
                    locks.insert(peer.id)
                } else {
                    locks.insert("\(peerID.displayName)#\(peerID.hash)")
                }
            }
            let peerName = availablePeers.first(where: { $0.peerId == peerID })?.winkName ?? peerID.displayName
            delivery = .delivered(payload.kind == .reply ? "Reply delivered" : peerName)
        } catch {
            delivery = .failed(peerID.displayName)
        }
    }

    private func unlock(peerID: MCPeerID) {
        locks.remove("\(peerID.displayName)#\(peerID.hash)")
        if let peer = availablePeers.first(where: { $0.peerId == peerID }) {
            locks.remove(peer.id)
        }
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

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {}
}

extension MultipeerManager: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(
        _ browser: MCNearbyServiceBrowser,
        foundPeer peerID: MCPeerID,
        withDiscoveryInfo info: [String: String]?
    ) {
        Task { @MainActor in
            let name = info?["nm"] ?? peerID.displayName
            let moderationID = info?["mid"]
            if moderation.isBlocked(name, moderationID: moderationID)
                || moderation.isBlocked(peerID.displayName, moderationID: moderationID) { return }
            // A peer advertising an objectionable display name never appears.
            if ContentFilter.check(name: name).isBlocked {
                moderation.noteFiltered()
                return
            }
            let peer = WinkPeer(
                peerId: peerID,
                winkName: name,
                atmosphere: info?["atm"] ?? "",
                moderationID: moderationID
            )
            if let index = availablePeers.firstIndex(where: { $0.peerId == peerID }) {
                availablePeers[index] = peer
            } else {
                availablePeers.append(peer)
            }
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
            let payload: WinkPayload
            if let decoded = try? JSONDecoder().decode(WinkPayload.self, from: data) {
                payload = decoded
            } else if let text = String(data: data, encoding: .utf8) {
                payload = .from(plain: text, fromName: peerID.displayName)
            } else {
                return
            }
            unlock(peerID: peerID)

            // Blocked senders can never reach the screen, even mid-session.
            if isBlocked(payload.fromName) || isBlocked(peerID.displayName) { return }
            if moderation.isBlocked(payload.fromName, moderationID: payload.senderModerationID) { return }

            // Screen incoming content before it is displayed. Anything that
            // matches the objectionable-content filter is dropped, never shown.
            if ContentFilter.check(payload: payload).isBlocked {
                moderation.noteFiltered()
                delivery = .blocked("Incoming content was blocked by WINK's safety filter.")
                return
            }

            moderation.remember(payload)
            incomingPeer = availablePeers.first(where: { $0.peerId == peerID })
                ?? WinkPeer(peerId: peerID, winkName: payload.fromName, atmosphere: payload.atmosphere)
            incoming = payload
        }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}
