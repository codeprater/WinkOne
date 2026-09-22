import CoreHaptics
import PencilKit
import PhotosUI
import SwiftUI
import UIKit

struct ContentView: View {
    @AppStorage("winkName") private var winkName = ""
    @AppStorage("winkOnboarded") private var onboarded = false
    @AppStorage("wink.agreedTermsVersion") private var agreedTermsVersion = ""
    @AppStorage("wink.profilePhotoData") private var profilePhotoData = Data()
    @StateObject private var manager = MultipeerManager()
    @StateObject private var location = LocationProvider()
    @ObservedObject private var moderation = ModerationStore.shared

    @State private var selectedAtmosphere = "Stadium"
    @State private var selectedDeckIndex = 0
    @State private var selectedCardIndex = 0
    @State private var isPulsing = false
    @State private var showNameSetup = false
    @State private var showOnboarding = false
    @State private var showPeerPicker = false
    @State private var showShareSheet = false
    @State private var messageImage: UIImage?
    @State private var shareItems: [Any] = []
    @State private var showConfetti = false
    @State private var engine: CHHapticEngine?
    @State private var selectedSymbol = WinkSymbol.send
    @State private var symbolCaption = ""
    @State private var drawing = PKDrawing()
    @State private var handwrittenCaption = ""
    @State private var linkText = ""
    @State private var safetySheet: SafetySheet?
    @State private var dockCollapsed = false

    /// Guideline 1.2: nothing can be composed or received until the user has
    /// accepted the current terms, which state the zero-tolerance policy.
    private var hasAgreed: Bool { agreedTermsVersion == WinkAgreement.version }

    private let allDecks = DeckLoader.loadDecks()
    private let atmospheres = DeckLoader.atmospheres

    private var visibleDecks: [WinkDeck] {
        allDecks.filter { $0.atmosphere == selectedAtmosphere }
    }

    private var currentDeck: WinkDeck {
        let decks = visibleDecks
        guard !decks.isEmpty else { return allDecks[0] }
        return decks[min(selectedDeckIndex, decks.count - 1)]
    }

    private var currentCard: WinkMessage {
        var card: WinkMessage
        if selectedAtmosphere == "Symbols" {
            card = WinkMessage(
                text: symbolCaption,
                pack: "Symbols",
                atmosphere: "Symbols",
                ink: .volt,
                symbolName: selectedSymbol
            )
        } else if selectedAtmosphere == "Links" {
            card = WinkMessage(
                text: LinkPaste.normalized(linkText) ?? linkText,
                pack: "Links",
                atmosphere: "Links",
                ink: .ice,
                symbolName: "link"
            )
        } else if selectedAtmosphere == "Handwritten" {
            card = WinkMessage(
                text: handwrittenCaption,
                pack: "Handwritten",
                atmosphere: "Handwritten",
                ink: .gold,
                drawingData: drawing.dataRepresentation()
            )
        } else {
            let cards = currentDeck.messages
            if cards.isEmpty {
                card = WinkMessage(text: "WINK", pack: "WINK", atmosphere: selectedAtmosphere, ink: .gold)
            } else {
                card = cards[min(selectedCardIndex, cards.count - 1)]
            }
        }
        if location.isSharing {
            card.latitude = location.latitude
            card.longitude = location.longitude
            card.placeName = location.placeName
        }
        return card
    }

    private var nearby: [WinkPeer] {
        manager.availablePeers.filter { peer in
            peer.atmosphere.isEmpty || peer.atmosphere == selectedAtmosphere
        }
    }

    var body: some View {
        ZStack {
            WinkColor.night.ignoresSafeArea()
            radar
                .allowsHitTesting(false)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 22)
                        .padding(.top, 8)
                    nearbyStrip
                        .padding(.top, 18)
                    if selectedAtmosphere != "Symbols" && selectedAtmosphere != "Handwritten" && selectedAtmosphere != "Links" {
                        Spacer(minLength: 12)
                    }
                    cardDeck
                        .frame(maxWidth: 390)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                    atmosphereRow
                        .padding(.top, 18)
                    packRow
                        .padding(.top, 10)
                }
            }

            if let incoming = manager.incoming {
                IncomingWinkView(
                    payload: incoming,
                    from: manager.incomingPeer,
                    onReply: { card in
                        if let peer = manager.incomingPeer {
                            send(card, to: peer, kind: .reply)
                        }
                        manager.dismissIncoming()
                    },
                    onReport: { safetySheet = .report(reportTargetForIncoming(incoming)) },
                    onBlock: { manager.blockCurrentSender() },
                    onRemove: { removeIncoming(incoming) },
                    onClose: { manager.dismissIncoming() }
                )
                .zIndex(2)
            }

            if showConfetti {
                ConfettiView()
                    .zIndex(3)
                    .allowsHitTesting(false)
            }

            deliveryToast
                .zIndex(4)

            if !hasAgreed {
                AgreementGateView(acceptedVersion: $agreedTermsVersion) {
                    if !onboarded {
                        showOnboarding = true
                    } else if winkName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        showNameSetup = true
                    } else {
                        manager.bootstrap(name: winkName, atmosphere: selectedAtmosphere)
                    }
                }
                .zIndex(10)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            dock
        }
        .onAppear {
            prepareHaptics()
            isPulsing = true
            WinkNotify.shared.configure()
            guard hasAgreed else { return }
            if !onboarded {
                showOnboarding = true
            } else if winkName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                showNameSetup = true
            } else {
                manager.bootstrap(name: winkName, atmosphere: selectedAtmosphere)
            }
        }
        .onChange(of: selectedAtmosphere) { _, newValue in
            selectedDeckIndex = 0
            selectedCardIndex = 0
            manager.setAtmosphere(newValue)
            if newValue != "Handwritten" {
                InkToolkit.hide()
            }
        }
        .onChange(of: manager.incoming) { _, incoming in
            if let incoming {
                let body = incoming.text.isEmpty ? (incoming.symbolName ?? "New WINK") : incoming.text
                WinkNotify.shared.announce(from: incoming.fromName, text: body)
            } else {
                WinkNotify.shared.clearBadge()
            }
        }
        .onChange(of: manager.delivery) { _, state in
            if case .delivered = state {
                playHapticSuccess()
                withAnimation { showConfetti = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    withAnimation { showConfetti = false }
                }
            }
            if state != .idle {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                    if manager.delivery == state {
                        manager.delivery = .idle
                    }
                }
            }
        }
        .sheet(item: $safetySheet) { sheet in
            switch sheet {
            case .center:
                SafetyCenterView(moderation: moderation) { safetySheet = nil }
            case .report(let target):
                ReportSheet(moderation: moderation, target: target)
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(name: $winkName) {
                onboarded = true
                showOnboarding = false
                manager.bootstrap(name: winkName, atmosphere: selectedAtmosphere)
            }
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showNameSetup) {
            NameSetupView(name: $winkName, photoData: $profilePhotoData) {
                manager.bootstrap(name: winkName, atmosphere: selectedAtmosphere)
            }
            .interactiveDismissDisabled(winkName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .sheet(isPresented: $showPeerPicker) {
            PeerPickerSheet(
                peers: nearby,
                locked: { manager.isLocked($0) },
                onPick: { peer in
                    send(currentCard, to: peer, kind: .wink)
                    showPeerPicker = false
                },
                onBlock: { manager.block($0) }
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityShareView(
                items: shareItems,
                nearbyTitle: "Nearby Wink",
                nearbyEnabled: !nearby.isEmpty,
                onNearby: {
                    showShareSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        showPeerPicker = true
                    }
                }
            )
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            profileAvatar
            VStack(alignment: .leading, spacing: 2) {
                Text("WINK")
                    .font(WinkFont.brand(34))
                    .tracking(4)
                    .foregroundStyle(WinkColor.volt)
                Button {
                    showNameSetup = true
                } label: {
                    Text(displayName.uppercased())
                        .font(WinkFont.label(11))
                        .tracking(1.8)
                        .foregroundStyle(.white.opacity(0.55))
                }

            }
            Spacer()
            if manager.incoming != nil {
                Image(systemName: WinkSymbol.inbox)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(WinkColor.volt)
                    .symbolEffect(.wiggle.byLayer, options: .repeating, isActive: true)
                    .padding(.trailing, 8)
            }
            Image(systemName: WinkSymbol.nearby)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle((!nearby.isEmpty && manager.isDiscoverable) ? WinkColor.volt : .white.opacity(0.28))
                .symbolEffect(.variableColor.iterative, isActive: !nearby.isEmpty && manager.isDiscoverable)
                .padding(.trailing, 10)
            Button {
                manager.toggleGhostMode()
            } label: {
                Image(systemName: manager.isDiscoverable ? "antenna.radiowaves.left.and.right" : "eye.slash")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(manager.isDiscoverable ? WinkColor.volt : .white.opacity(0.35))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(manager.isDiscoverable ? "Ghost Mode Off" : "Ghost Mode On")
            Button {
                safetySheet = .center
            } label: {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Safety Center: report, block, remove, contact")
        }
    }

    private var profileAvatar: some View {
            Group {
                if let image = UIImage(data: profilePhotoData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            .frame(width: 38, height: 38)
            .clipShape(Circle())
            .overlay(Circle().stroke(WinkColor.volt.opacity(0.7), lineWidth: 1))
            .accessibilityLabel("Profile photo")
    }

    private var displayName: String {
        let name = winkName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Set your name" : name
    }

    private var nearbyStrip: some View {
        Group {
            if nearby.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: WinkSymbol.nearby)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.35))
                    Text(manager.isDiscoverable
                         ? "Nobody on \(selectedAtmosphere) yet. Hit Send to AirDrop or iMessage."
                         : "Ghost Mode. You're off the radar.")
                        .font(WinkFont.body(13))
                        .foregroundStyle(.white.opacity(0.45))
                }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .frame(height: 72)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 18) {
                        ForEach(nearby) { peer in
                            Button {
                                send(currentCard, to: peer, kind: .wink)
                            } label: {
                                VStack(spacing: 8) {
                                    ZStack {
                                        Circle()
                                            .fill(manager.isLocked(peer) ? Color.white.opacity(0.12) : WinkColor.volt)
                                            .frame(width: 52, height: 52)
                                        Text(String(peer.winkName.prefix(1)).uppercased())
                                            .font(WinkFont.brand(20))
                                            .foregroundStyle(manager.isLocked(peer) ? .white.opacity(0.4) : WinkColor.night)
                                    }
                                    Text(peer.winkName)
                                        .font(WinkFont.label(10))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                        .frame(width: 68)
                                    if manager.isLocked(peer) {
                                        Text("ONE SHOT")
                                            .font(WinkFont.label(8))
                                            .tracking(0.8)
                                            .foregroundStyle(WinkColor.volt.opacity(0.7))
                                    }
                                }
                            }
                            .disabled(manager.isLocked(peer))
                            .contextMenu {
                                Button("Ignore", role: .destructive) {
                                    manager.block(peer)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 22)
                }
                .frame(height: 96)
            }
        }
    }

    private var cardDeck: some View {
        Group {
            if selectedAtmosphere == "Symbols" {
                SymbolStudio(
                    selectedName: $selectedSymbol,
                    caption: $symbolCaption,
                    fromName: displayName,
                    placeName: location.isSharing ? location.placeName : nil
                )
            } else if selectedAtmosphere == "Links" {
                LinkStudio(
                    linkText: $linkText,
                    fromName: displayName,
                    placeName: location.isSharing ? location.placeName : nil
                )
            } else if selectedAtmosphere == "Handwritten" {
                HandwrittenStudio(
                    drawing: $drawing,
                    caption: $handwrittenCaption,
                    toolkitActive: true
                )
            } else {
                TabView(selection: $selectedCardIndex) {
                    ForEach(Array(currentDeck.messages.enumerated()), id: \.element.id) { index, wink in
                        WinkCardView(message: decorated(wink), fromName: displayName)
                            .tag(index)
                            .padding(.bottom, 8)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 440)
                .frame(maxWidth: 360)
            }
        }
    }

    private var dock: some View {
        VStack(spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    dockCollapsed.toggle()
                }
            } label: {
                Image(systemName: dockCollapsed ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 44, height: 24)
            }
            .accessibilityLabel(dockCollapsed ? "Expand action dock" : "Collapse action dock")

            if !dockCollapsed {
                actionRow
                    .padding(.horizontal, 22)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .background(.ultraThinMaterial)
    }

    private var atmosphereRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 22) {
                ForEach(atmospheres) { atmosphere in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedAtmosphere = atmosphere.name
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Text(atmosphere.name.uppercased())
                                .font(WinkFont.label(11))
                                .tracking(1.4)
                                .foregroundStyle(selectedAtmosphere == atmosphere.name ? WinkColor.volt : .white.opacity(0.38))
                            Rectangle()
                                .fill(selectedAtmosphere == atmosphere.name ? WinkColor.volt : Color.clear)
                                .frame(height: 2)
                        }
                    }
                }
            }
            .padding(.horizontal, 22)
        }
    }

    private var packRow: some View {
        Group {
            if selectedAtmosphere == "Symbols" || selectedAtmosphere == "Handwritten" || selectedAtmosphere == "Links" {
                EmptyView()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 18) {
                        ForEach(Array(visibleDecks.enumerated()), id: \.element.id) { index, deck in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedDeckIndex = index
                                    selectedCardIndex = 0
                                }
                            } label: {
                                Text(deck.name.uppercased())
                                    .font(WinkFont.label(12))
                                    .tracking(1.2)
                                    .foregroundStyle(selectedDeckIndex == index ? .white : .white.opacity(0.35))
                            }
                        }
                    }
                    .padding(.horizontal, 22)
                }
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button {
                location.toggle()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: location.isSharing ? "mappin.circle.fill" : "mappin")
                        .font(.system(size: 18, weight: .semibold))
                        .symbolEffect(.bounce, value: location.isSharing)
                    Text(location.isSharing ? (location.placeName ?? "Locating") : "Place")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                }
                .foregroundStyle(location.isSharing ? WinkColor.volt : .white.opacity(0.45))
                .frame(width: 72)
            }
            .accessibilityLabel(location.isSharing ? "Location on" : "Add location")

            Button(action: presentSendSheet) {
                HStack(spacing: 8) {
                    Image(systemName: WinkSymbol.send)
                        .font(.system(size: 16, weight: .bold))
                    Text("SEND")
                        .font(WinkFont.label(13))
                        .tracking(1.2)
                }
                .foregroundStyle(WinkColor.night)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(WinkColor.volt)
            }
        }
    }

    @ViewBuilder
    private var deliveryToast: some View {
        switch manager.delivery {
        case .idle:
            EmptyView()
        case .sending(let name):
            toast("Sending to \(name)…")
        case .delivered(let name):
            toast(name == "Reply delivered" ? "REPLY DELIVERED" : "DELIVERED TO \(name.uppercased())")
        case .failed(let name):
            toast("Couldn't reach \(name)")
        case .locked(let name):
            toast("One shot with \(name). Wait for a wink back.")
        case .blocked(let reason):
            toast(reason)
        }
    }

    private func toast(_ text: String) -> some View {
        Text(text)
            .font(WinkFont.label(12))
            .tracking(1)
            .foregroundStyle(WinkColor.volt)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(WinkColor.night)
            .padding(.horizontal, 24)
            .padding(.bottom, 110)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .transition(.opacity)
    }

    private var radar: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(WinkColor.volt.opacity(0.12), lineWidth: 1)
                    .scaleEffect(isPulsing ? 1.8 : 0.7)
                    .opacity(isPulsing ? 0 : 0.55)
                    .animation(
                        .easeOut(duration: 3.2).repeatForever(autoreverses: false).delay(Double(i) * 0.55),
                        value: isPulsing
                    )
            }
        }
        .frame(height: 420)
        .offset(y: -90)
        .allowsHitTesting(false)
    }

    private func decorated(_ card: WinkMessage) -> WinkMessage {
        var next = card
        if location.isSharing {
            next.latitude = location.latitude
            next.longitude = location.longitude
            next.placeName = location.placeName
        }
        return next
    }

    private func send(_ card: WinkMessage, to peer: WinkPeer, kind: WinkPayload.Kind) {
        if let reason = ContentFilter.check(message: card).reason {
            moderation.noteFiltered()
            manager.delivery = .blocked(reason)
            return
        }
        let payload = WinkPayload(
            text: card.text,
            pack: card.pack,
            atmosphere: card.atmosphere,
            ink: card.ink,
            fromName: MultipeerManager.sanitizedName(winkName),
            kind: kind,
            symbolName: card.symbolName,
            drawingData: card.drawingData,
            latitude: card.latitude,
            longitude: card.longitude,
            placeName: card.placeName
        )
        manager.send(payload, to: peer)
        playHapticSuccess()
    }

    private func presentSendSheet() {
        let card = currentCard
        // Screen the card before it can reach the share sheet.
        if let reason = ContentFilter.check(message: card).reason {
            moderation.noteFiltered()
            manager.delivery = .blocked(reason)
            return
        }
        if ContentFilter.check(name: winkName).isBlocked {
            manager.delivery = .blocked("That display name isn't allowed on WINK.")
            showNameSetup = true
            return
        }
        guard let image = CardRenderer.image(
            for: card,
            fromName: MultipeerManager.sanitizedName(winkName)
        ) else { return }
        messageImage = image
        var items: [Any] = [image]
        let line = card.text.isEmpty ? "WINK" : card.text
        items.append("WINK from \(displayName): \(line)")
        if let url = card.linkURL {
            items.append(url)
        }
        if let url = card.mapsURL {
            items.append(url)
        }
        shareItems = items
        showShareSheet = true
    }

    private func reportTargetForIncoming(_ payload: WinkPayload) -> ReportTarget {
        var parts: [String] = []
        if !payload.text.isEmpty { parts.append(payload.text) }
        if let symbol = payload.symbolName { parts.append("symbol: \(symbol)") }
        if let place = payload.placeName { parts.append("place: \(place)") }
        parts.append("pack: \(payload.pack) / \(payload.atmosphere)")
        let contentID = moderation.received.first(where: { $0.payload == payload })?.id
        manager.dismissIncoming()
        return ReportTarget(name: payload.fromName, evidence: parts.joined(separator: " \u{2022} "), contentID: contentID)
    }

    /// Guideline 1.2: remove a card from the device immediately.
    private func removeIncoming(_ payload: WinkPayload) {
        if let stored = moderation.received.first(where: { $0.payload == payload }) {
            moderation.remove(stored)
        }
        manager.dismissIncoming()
    }

    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {}
    }

    private func playHapticSuccess() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics, let engine else { return }
        do {
            let events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)],
                    relativeTime: 0
                )
            ]
            let player = try engine.makePlayer(with: try CHHapticPattern(events: events, parameters: []))
            try player.start(atTime: 0)
        } catch {}
    }
}

enum SafetySheet: Identifiable {
    case center
    case report(ReportTarget)

    var id: String {
        switch self {
        case .center: "center"
        case .report(let target): target.id.uuidString
        }
    }
}

struct NameSetupView: View {
    @Binding var name: String
    @Binding var photoData: Data
    var onDone: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @State private var nameError: String?
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        ZStack {
            WinkColor.night.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 24) {
                Text("WINK")
                    .font(WinkFont.brand(42))
                    .tracking(5)
                    .foregroundStyle(WinkColor.volt)
                Text("What should people see?")
                    .font(WinkFont.shout(28))
                    .foregroundStyle(.white)
                TextField("First name or handle", text: $draft)
                    .font(WinkFont.body(22))
                    .foregroundStyle(.white)
                    .tint(WinkColor.volt)
                    .padding(.vertical, 12)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(WinkColor.volt).frame(height: 2)
                    }
                PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                    HStack(spacing: 10) {
                        if let image = UIImage(data: photoData) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 54, height: 54)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "photo.circle.fill")
                                .font(.system(size: 30))
                        }
                        Text(photoData.isEmpty ? "ADD NAME TAG PHOTO" : "CHANGE NAME TAG PHOTO")
                            .font(WinkFont.label(12))
                            .tracking(1)
                    }
                    .foregroundStyle(WinkColor.volt)
                }
                .onChange(of: photoItem) { _, item in
                    guard let item else { return }
                    Task {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data),
                           let jpeg = image.jpegData(compressionQuality: 0.82) {
                            await MainActor.run { photoData = jpeg }
                        }
                    }
                }
                if let nameError {
                    Text(nameError)
                        .font(WinkFont.body(14))
                        .foregroundStyle(WinkColor.ember)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button {
                    if let reason = ContentFilter.check(name: draft).reason {
                        nameError = reason
                        return
                    }
                    nameError = nil
                    name = draft
                    onDone()
                    dismiss()
                } label: {
                    Text("THAT'S ME")
                        .font(WinkFont.label(14))
                        .tracking(1.6)
                        .foregroundStyle(WinkColor.night)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(WinkColor.volt)
                }
            }
            .padding(28)
        }
        .onAppear { draft = name }
    }
}

struct PeerPickerSheet: View {
    let peers: [WinkPeer]
    var locked: (WinkPeer) -> Bool
    var onPick: (WinkPeer) -> Void
    var onBlock: (WinkPeer) -> Void

    var body: some View {
        NavigationStack {
            List(peers) { peer in
                HStack {
                    Button {
                        if !locked(peer) { onPick(peer) }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(peer.winkName)
                                .font(WinkFont.body(17))
                                .foregroundStyle(.primary)
                            if locked(peer) {
                                Text("One shot — waiting on a wink back")
                                    .font(WinkFont.label(11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .disabled(locked(peer))
                    Spacer()
                    Button("Ignore") { onBlock(peer) }
                        .font(WinkFont.label(12))
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Send to")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct IncomingWinkView: View {
    let payload: WinkPayload
    let from: WinkPeer?
    var onReply: (WinkMessage) -> Void
    var onReport: () -> Void
    var onBlock: () -> Void
    var onRemove: () -> Void
    var onClose: () -> Void

    @State private var replyIndex = 0
    @State private var opened = false

    private var replyDeck: [WinkMessage] {
        if payload.symbolName != nil {
            return [
                WinkMessage(text: "Heard.", pack: "Symbols", atmosphere: "Symbols", ink: .volt, symbolName: "heart.fill"),
                WinkMessage(text: "AYO", pack: "Symbols", atmosphere: "Symbols", ink: .volt, symbolName: "hand.wave.fill"),
                WinkMessage(text: "", pack: "Symbols", atmosphere: "Symbols", ink: .volt, symbolName: WinkSymbol.send)
            ]
        }
        return DeckLoader.pack(payload.pack, in: payload.atmosphere)?.messages ?? []
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: WinkSymbol.inbox)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(WinkColor.volt)
                    .symbolEffect(.wiggle.byLayer, options: .repeating, isActive: true)
                Text(payload.fromName.uppercased())
                    .font(WinkFont.label(12))
                    .tracking(2)
                    .foregroundStyle(WinkColor.volt)

                WinkCardView(message: payload.asMessage, fromName: payload.fromName)
                    .padding(.horizontal, 36)
                    .scaleEffect(opened ? 1 : 0.86)
                    .opacity(opened ? 1 : 0.4)
                    .onTapGesture {
                        if let url = payload.asMessage.linkURL {
                            UIApplication.shared.open(url)
                        }
                    }

                if let url = payload.asMessage.linkURL {
                    Button {
                        UIApplication.shared.open(url)
                    } label: {
                        Text("OPEN LINK")
                            .font(WinkFont.label(13))
                            .tracking(1.4)
                            .foregroundStyle(WinkColor.night)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(WinkColor.volt)
                    }
                    .padding(.horizontal, 36)
                }

                if from != nil, !replyDeck.isEmpty {
                    VStack(spacing: 10) {
                        Text("REPLY")
                            .font(WinkFont.label(11))
                            .tracking(2)
                            .foregroundStyle(.white.opacity(0.5))
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(Array(replyDeck.enumerated()), id: \.element.id) { index, card in
                                    Button {
                                        replyIndex = index
                                    } label: {
                                        HStack(spacing: 6) {
                                            if let symbol = card.symbolName {
                                                Image(systemName: symbol)
                                                    .font(.system(size: 14, weight: .semibold))
                                            }
                                            if !card.text.isEmpty {
                                                Text(card.text)
                                                    .font(WinkFont.label(12))
                                            }
                                        }
                                        .foregroundStyle(replyIndex == index ? WinkColor.night : .white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(replyIndex == index ? WinkColor.volt : Color.white.opacity(0.12))
                                    }
                                }
                            }
                            .padding(.horizontal, 22)
                        }
                    }

                    Button {
                        onReply(replyDeck[min(replyIndex, replyDeck.count - 1)])
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: WinkSymbol.send)
                            Text("SEND REPLY")
                        }
                        .font(WinkFont.label(13))
                        .tracking(1.4)
                        .foregroundStyle(WinkColor.night)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(WinkColor.volt)
                    }
                    .padding(.horizontal, 36)
                }

                HStack(spacing: 18) {
                    Button(action: onReport) {
                        Label("REPORT", systemImage: "exclamationmark.triangle.fill")
                            .font(WinkFont.label(11))
                            .tracking(1.2)
                            .foregroundStyle(WinkColor.ember)
                    }
                    .accessibilityHint("Report this card as objectionable and block the sender")

                    Button(action: onBlock) {
                        Label("BLOCK", systemImage: "hand.raised.fill")
                            .font(WinkFont.label(11))
                            .tracking(1.2)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .accessibilityHint("Block this user from contacting you again")

                    Button(action: onRemove) {
                        Label("REMOVE", systemImage: "trash.fill")
                            .font(WinkFont.label(11))
                            .tracking(1.2)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .accessibilityHint("Remove this card from your device immediately")
                }
                .padding(.top, 4)

                Button("CLOSE", action: onClose)
                    .font(WinkFont.label(13))
                    .tracking(1.6)
                    .foregroundStyle(.white)
                    .padding(.bottom, 8)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                opened = true
            }
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
    }
}

struct ConfettiView: View {
    private let colors: [Color] = [WinkColor.volt, WinkColor.ember, WinkColor.ice, .white]

    var body: some View {
        ZStack {
            ForEach(0..<18, id: \.self) { i in
                Rectangle()
                    .fill(colors[i % colors.count])
                    .frame(width: 6, height: 10)
                    .modifier(ParticlesModifier(index: i))
            }
        }
        .allowsHitTesting(false)
    }
}

struct ParticlesModifier: ViewModifier {
    let index: Int
    @State private var time = 0.0
    @State private var scale = 0.1
    @State private var xFactor = Double.random(in: -180...180)
    @State private var yFactor = Double.random(in: -360...360)

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .offset(x: xFactor * time, y: yFactor * time)
            .opacity(1 - time)
            .onAppear {
                withAnimation(.easeOut(duration: 1.4)) {
                    time = 1.0
                    scale = 1.0
                }
            }
    }
}

#Preview {
    ContentView()
}
