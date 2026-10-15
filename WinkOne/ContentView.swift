import CoreHaptics
import PencilKit
import SwiftUI
import UIKit

struct ContentView: View {
    @AppStorage("winkName") private var winkName = ""
    @AppStorage("winkOnboarded") private var onboarded = false
    @AppStorage("wink.agreedTermsVersion") private var agreedTermsVersion = ""
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

    // 2.0 composers
    @State private var voiceData: Data?
    @State private var voiceDuration: TimeInterval = 0
    @State private var voiceLevels: [CGFloat] = []
    @State private var voiceCaption = ""
    @State private var photoData: Data?
    @State private var photoCaption = ""
    @State private var photoSymbol: String?
    @State private var moodHex = MoodPalette.defaultHex
    @State private var moodWord = ""
    @State private var emojiSequence = ""
    @State private var genmojiData: Data?
    @State private var zodiacSign = Zodiac.aries.rawValue
    @State private var zodiacCaption = ""
    @State private var nameTagPhoto: Data?
    @State private var nameTagName = ""

    /// Secret Wink modifier. Applies to whichever composer is active.
    @State private var secretUntilTapped = false

    /// The dock collapses to a pill when the radar has the floor.
    @State private var dockExpanded = true
    @State private var showInbox = false
    /// The dock steps aside while the keyboard is up, so it never covers
    /// the field someone is typing into.
    @State private var keyboardUp = false
    @State private var dockHidden = false
    @State private var idleTask: Task<Void, Never>?
    @State private var showLibrary = false
    @State private var restoringCard = false
    @AppStorage("wink.dockAutoHide") private var dockAutoHide = true
    @Environment(\.scenePhase) private var scenePhase

    /// Which composer the atmosphere string currently names.
    private var composer: Composer { Composer(atmosphere: selectedAtmosphere) }

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

        switch composer {
        case .symbols:
            card = WinkMessage(
                text: symbolCaption,
                pack: "Symbols",
                atmosphere: composer.atmosphere,
                ink: composer.ink,
                symbolName: selectedSymbol
            )
        case .links:
            card = WinkMessage(
                text: LinkPaste.normalized(linkText) ?? linkText,
                pack: "Links",
                atmosphere: composer.atmosphere,
                ink: composer.ink,
                symbolName: "link"
            )
        case .handwritten:
            card = WinkMessage(
                text: handwrittenCaption,
                pack: "Handwritten",
                atmosphere: composer.atmosphere,
                ink: composer.ink,
                drawingData: drawing.dataRepresentation()
            )
        case .voice:
            // `text` doubles as the v1 fallback: a build-10 client cannot play
            // audio, so it renders this line instead of an empty card.
            card = WinkMessage(
                text: voiceCaption.isEmpty ? "Voice WINK. Update WINK to hear it" : voiceCaption,
                pack: "Voice",
                atmosphere: composer.atmosphere,
                ink: composer.ink,
                voiceData: voiceData,
                voiceDuration: voiceDuration > 0 ? voiceDuration : nil
            )
        case .photo:
            card = WinkMessage(
                text: photoCaption.isEmpty ? "Photo WINK. Update WINK to see it" : photoCaption,
                pack: "Photo",
                atmosphere: composer.atmosphere,
                ink: composer.ink,
                photoData: photoData,
                photoCaption: photoCaption.isEmpty ? nil : photoCaption,
                photoSymbolName: photoSymbol
            )
        case .mood:
            card = WinkMessage(
                text: moodWord,
                pack: "Mood",
                atmosphere: composer.atmosphere,
                ink: composer.ink,
                moodColorHex: moodHex,
                moodWord: moodWord.isEmpty ? nil : moodWord
            )
        case .emoji:
            card = WinkMessage(
                text: emojiSequence,
                pack: "Emoji",
                atmosphere: composer.atmosphere,
                ink: composer.ink,
                emojiSequence: emojiSequence.isEmpty ? nil : emojiSequence,
                genmojiData: genmojiData
            )
        case .zodiac:
            card = WinkMessage(
                text: zodiacCaption.isEmpty ? (Zodiac.named(zodiacSign)?.line ?? "") : zodiacCaption,
                pack: "Zodiac",
                atmosphere: composer.atmosphere,
                ink: composer.ink,
                zodiacSign: zodiacSign
            )
        case .nameTag:
            let tagName = nameTagName.isEmpty ? displayName : nameTagName
            card = WinkMessage(
                text: tagName,
                pack: "Name Tag",
                atmosphere: composer.atmosphere,
                ink: composer.ink,
                photoData: nameTagPhoto,
                nameTagName: tagName
            )
        case .stadium, .lounge, .dailyGrind, .genZ:
            let cards = currentDeck.messages
            if cards.isEmpty {
                card = WinkMessage(text: "WINK", pack: "WINK", atmosphere: composer.atmosphere, ink: .gold)
            } else {
                card = cards[min(selectedCardIndex, cards.count - 1)]
            }
        }

        card.secretUntilTapped = secretUntilTapped

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
            WinkRadar(
                peers: nearby,
                isLocked: { manager.isLocked($0) },
                isDiscoverable: manager.isDiscoverable,
                onSelect: { peer in send(currentCard, to: peer, kind: .wink) },
                onBlock: { peer in manager.block(peer) },
                onBackgroundTap: {
                    // Never sweep the tools away while someone is making a card.
                    guard composer.isDeck else { return }
                    stopIdleTimer()
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.85)) {
                        dockExpanded = false
                        dockHidden = true
                    }
                }
            )

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 22)
                    .padding(.top, 8)

                // One flexible region between the header and the dock. Each
                // composer measures this region itself, so the card and its
                // tools always fit in what is actually left.
                cardDeck
                    .padding(.horizontal, composer.isStudio ? 0 : 28)
                    .frame(maxHeight: .infinity)

                // Room for the dock, reserved once, so nothing sits under it.
                Color.clear.frame(height: dockRoom)
            }
            .onChange(of: dockExpanded) { _, expanded in
                if expanded { nudgeDock() }
            }
            .onChange(of: selectedAtmosphere) { _, _ in nudgeDock(expand: true) }
            .onDisappear { stopIdleTimer() }

            if !keyboardUp {
                VStack {
                    Spacer()
                    WinkDock(
                        isExpanded: $dockExpanded,
                        isHidden: $dockHidden,
                        selectedAtmosphere: $selectedAtmosphere,
                        selectedDeckIndex: $selectedDeckIndex,
                        selectedCardIndex: $selectedCardIndex,
                        secretUntilTapped: $secretUntilTapped,
                        visibleDecks: visibleDecks,
                        unreadCount: moderation.received.count,
                        locationSharing: location.isSharing,
                        locationLabel: location.isSharing ? (location.placeName ?? "Locating") : "Place",
                        onToggleLocation: { location.toggle() },
                        onSend: presentSendSheet,
                        onOpenInbox: { showInbox = true }
                    )
                }
                .zIndex(1)
                .transition(.move(edge: .bottom).combined(with: .opacity))
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
                    onClose: { manager.dismissIncoming() },
                    waitingCount: manager.waitingCount
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
        .onAppear {
            prepareHaptics()
            isPulsing = true
            WinkNotify.shared.configure()
            nudgeDock()
            guard hasAgreed else { return }
            if !onboarded {
                showOnboarding = true
            } else if winkName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                showNameSetup = true
            } else {
                manager.bootstrap(name: winkName, atmosphere: selectedAtmosphere)
            }
        }
        .background(watchSync)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeOut(duration: 0.2)) { keyboardUp = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.2)) { keyboardUp = false }
        }
        .onChange(of: selectedAtmosphere) { _, newValue in
            // load() sets the atmosphere and then aims at an exact card, so it
            // raises this flag to keep the reset from landing on top of it.
            if restoringCard {
                restoringCard = false
            } else {
                selectedDeckIndex = 0
                selectedCardIndex = 0
            }
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
        .sheet(isPresented: $showLibrary) {
            WinkLibrary(
                peers: nearby,
                fromName: displayName,
                onUse: { card in
                    showLibrary = false
                    load(card)
                },
                onQuickSend: { card, peer in
                    showLibrary = false
                    send(card, to: peer, kind: .wink)
                },
                onClose: { showLibrary = false }
            )
        }
        .onChange(of: scenePhase) { _, phase in
            // Coming back from the background is where discovery usually dies.
            if phase == .active {
                manager.wake()
                nudgeDock(expand: true)
            } else {
                stopIdleTimer()
            }
        }
        .onChange(of: showLibrary) { _, open in
            if open { stopIdleTimer() } else { nudgeDock(expand: true) }
        }
        .sheet(isPresented: $showInbox) {
            InboxView(
                moderation: moderation,
                onReport: { wink in
                    showInbox = false
                    safetySheet = .report(ReportTarget(
                        name: wink.fromName,
                        evidence: wink.payload.text
                    ))
                },
                onDismiss: { showInbox = false }
            )
        }
        .fullScreenCover(item: $safetySheet) { sheet in
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
            NameSetupView(name: $winkName) {
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
                onBlock: { manager.block($0) },
                onCancel: { showPeerPicker = false }
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

    /// WINK and your name on the left, the three screen-level tools on the
    /// right. Inbox lives in the dock, so it is not repeated here.
    private var header: some View {
        HStack(alignment: .center, spacing: 6) {
            VStack(alignment: .leading, spacing: 0) {
                Text("WINK")
                    .font(WinkFont.brand(34))
                    .tracking(4)
                    .foregroundStyle(WinkColor.volt)
                    // Futura-Bold at 34 with 4pt tracking can overrun on a Pro
                    // Max. One line, shrink if it has to.
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .minimumScaleFactor(0.6)
                Button {
                    showNameSetup = true
                } label: {
                    Text(displayName.uppercased())
                        .font(WinkFont.label(12))
                        .tracking(1.6)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(minHeight: 32, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Your name, \(displayName)")
                .accessibilityHint("Change the name people see")
            }

            Spacer(minLength: 8)

            headerButton(
                "square.grid.2x2",
                tint: .white.opacity(0.8),
                label: "Your winks: recent, shared, and every pack"
            ) {
                stopIdleTimer()
                showLibrary = true
            }

            headerButton(
                manager.isDiscoverable ? "antenna.radiowaves.left.and.right" : "eye.slash",
                tint: manager.isDiscoverable ? WinkColor.volt : .white.opacity(0.6),
                label: manager.isDiscoverable ? "Ghost Mode is off. You are visible" : "Ghost Mode is on. You are hidden"
            ) {
                manager.toggleGhostMode()
            }

            headerButton(
                "shield.lefthalf.filled",
                tint: .white.opacity(0.8),
                label: "Safety Center: report, block, remove, contact"
            ) {
                safetySheet = .center
            }
        }
    }

    private func headerButton(
        _ icon: String,
        tint: Color,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.white.opacity(0.08)))
                .contentShape(Circle())
        }
        .accessibilityLabel(label)
    }

    private var dockRoom: CGFloat {
        if keyboardUp { return 0 }
        if dockHidden { return 44 }
        if !dockExpanded { return 78 }
        // The pack row only shows for the ready-made packs.
        return composer.isDeck && !visibleDecks.isEmpty ? 214 : 176
    }

    /// The dock gets out of the way on its own. Any touch brings it back, then
    /// it steps down a rung at a time: expanded for five seconds of quiet,
    /// collapsed for four more, then just the grab tab. Cancelled and restarted
    /// on every interaction, so it never disappears mid-tap.
    private func nudgeDock(expand: Bool = false) {
        idleTask?.cancel()
        if expand { dockExpanded = true }
        if dockHidden { dockHidden = false }
        // Auto-hide is for browsing packs. While someone is making a card the
        // tools and Send stay put.
        guard dockAutoHide, composer.isDeck else { return }
        idleTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.85)) { dockExpanded = false }
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) { dockHidden = true }
        }
    }

    private func stopIdleTimer() {
        idleTask?.cancel()
        idleTask = nil
    }


    private var displayName: String {
        let name = winkName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Set your name" : name
    }

    private var cardDeck: some View {
        Group {
            switch composer {
            case .symbols:
                SymbolStudio(
                    selectedName: $selectedSymbol,
                    caption: $symbolCaption,
                    fromName: displayName,
                    placeName: location.isSharing ? location.placeName : nil
                )
            case .links:
                LinkStudio(
                    linkText: $linkText,
                    fromName: displayName,
                    placeName: location.isSharing ? location.placeName : nil
                )
            case .handwritten:
                HandwrittenStudio(
                    drawing: $drawing,
                    caption: $handwrittenCaption,
                    toolkitActive: true
                )
            case .voice:
                VoiceStudio(
                    voiceData: $voiceData,
                    voiceDuration: $voiceDuration,
                    caption: $voiceCaption,
                    bakedLevels: $voiceLevels,
                    fromName: displayName,
                    placeName: location.isSharing ? location.placeName : nil
                )
            case .photo:
                PhotoStudio(
                    photoData: $photoData,
                    caption: $photoCaption,
                    overlaySymbol: $photoSymbol,
                    fromName: displayName,
                    placeName: location.isSharing ? location.placeName : nil,
                    onReject: { reason in manager.delivery = .blocked(reason) }
                )
            case .mood:
                MoodStudio(
                    colorHex: $moodHex,
                    word: $moodWord,
                    fromName: displayName,
                    placeName: location.isSharing ? location.placeName : nil
                )
            case .emoji:
                EmojiStudio(
                    sequence: $emojiSequence,
                    genmojiData: $genmojiData,
                    fromName: displayName,
                    placeName: location.isSharing ? location.placeName : nil
                )
            case .zodiac:
                ZodiacStudio(
                    sign: $zodiacSign,
                    caption: $zodiacCaption,
                    fromName: displayName,
                    placeName: location.isSharing ? location.placeName : nil
                )
            case .nameTag:
                NameTagStudio(
                    photoData: $nameTagPhoto,
                    name: $nameTagName,
                    fromName: displayName,
                    placeName: location.isSharing ? location.placeName : nil,
                    onReject: { reason in manager.delivery = .blocked(reason) }
                )
            case .stadium, .lounge, .dailyGrind, .genZ:
                // Sized from the space really left between header and dock,
                // and centered in it, so the deck never runs under the dock.
                GeometryReader { geo in
                    let fit = min(geo.size.height - 8, geo.size.width / InviteCard.aspectRatio + 8)
                    TabView(selection: $selectedCardIndex) {
                        ForEach(Array(currentDeck.messages.enumerated()), id: \.element.id) { index, wink in
                            WinkCardView(message: decorated(wink), fromName: displayName)
                                .tag(index)
                                .padding(.bottom, 8)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: max(0, fit))
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
                }
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
        // Every 2.0 field has to ride along, or a Voice Wink arrives silent, a
        // Mood card arrives grey and an Emoji card arrives empty. A v1 client
        // ignores what it does not know, which is why these are all optional.
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
            placeName: card.placeName,
            voiceData: card.voiceData,
            voiceDuration: card.voiceDuration,
            photoData: card.photoData,
            photoCaption: card.photoCaption,
            photoSymbolName: card.photoSymbolName,
            moodColorHex: card.moodColorHex,
            moodWord: card.moodWord,
            emojiSequence: card.emojiSequence,
            zodiacSign: card.zodiacSign,
            nameTagName: card.nameTagName,
            genmojiData: card.genmojiData,
            secretUntilTapped: card.secretUntilTapped
        )
        manager.send(payload, to: peer)
        moderation.noteSent(payload, to: peer.winkName)
        playHapticSuccess()
    }

    /// Long-press "Open in Composer" — drop a card back into whichever studio
    /// made it, with its own fields restored, not just its text.
    private func load(_ card: WinkMessage) {
        restoringCard = card.atmosphere != selectedAtmosphere
        selectedAtmosphere = card.atmosphere
        secretUntilTapped = card.secretUntilTapped

        switch Composer(atmosphere: card.atmosphere) {
        case .symbols:
            selectedSymbol = card.symbolName ?? WinkSymbol.send
            symbolCaption = card.text
        case .links:
            linkText = card.text
        case .handwritten:
            if let data = card.drawingData, let restored = try? PKDrawing(data: data) {
                drawing = restored
            }
            handwrittenCaption = card.text
        case .voice:
            voiceData = card.voiceData
            voiceDuration = card.voiceDuration ?? 0
            voiceLevels = []
            voiceCaption = card.text
        case .photo:
            photoData = card.photoData
            photoCaption = card.photoCaption ?? ""
            photoSymbol = card.photoSymbolName
        case .mood:
            moodHex = card.moodColorHex ?? MoodPalette.defaultHex
            moodWord = card.moodWord ?? card.text
        case .emoji:
            emojiSequence = card.emojiSequence ?? ""
            genmojiData = card.genmojiData
        case .zodiac:
            zodiacSign = card.zodiacSign ?? Zodiac.aries.rawValue
            zodiacCaption = card.text
        case .nameTag:
            nameTagPhoto = card.photoData
            nameTagName = card.nameTagName ?? ""
        case .stadium, .lounge, .dailyGrind, .genZ:
            // Land on the exact card in the exact pack, not just the pack.
            if let deckIndex = visibleDecks.firstIndex(where: { $0.name == card.pack }) {
                selectedDeckIndex = deckIndex
                if let cardIndex = visibleDecks[deckIndex].messages.firstIndex(where: { $0.id == card.id }) {
                    selectedCardIndex = cardIndex
                } else {
                    selectedCardIndex = 0
                }
            }
        }
        nudgeDock(expand: true)
    }

    private func presentSendSheet() {
        let card = currentCard

        // AirDrop and Messages handle a bare audio item inconsistently, so
        // Voice stays on the Nearby rail until that is verified on device.
        if composer == .voice {
            manager.delivery = .blocked("Voice Winks are Nearby only.")
            return
        }

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
        // The compressed JPEG travels alongside the rendered card.
        if let photo = card.photoData {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("wink-photo-\(UUID().uuidString).jpg")
            if (try? photo.write(to: url)) != nil {
                items.append(url)
            }
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
        manager.dismissIncoming()
        return ReportTarget(name: payload.fromName, evidence: parts.joined(separator: " \u{2022} "))
    }

    // MARK: Apple Watch

    /// Invisible view that keeps the watch's picture of the inbox, the radar
    /// and Ghost Mode current. Kept out of `body` so the type checker does
    /// not have to carry it.
    private var watchSync: some View {
        Color.clear
            .onAppear {
                WatchLink.shared.onCommand = { command in handleWatch(command) }
                WatchLink.shared.activate()
                pushWatchState()
            }
            .onChange(of: moderation.received) { _, _ in pushWatchState() }
            .onChange(of: manager.availablePeers) { _, _ in pushWatchState() }
            .onChange(of: manager.isDiscoverable) { _, _ in pushWatchState() }
            .onChange(of: winkName) { _, _ in pushWatchState() }
    }

    private func pushWatchState() {
        let winks: [WatchWink] = moderation.received.prefix(20).map { wink in
            let p = wink.payload
            return WatchWink(
                id: wink.id,
                fromName: p.fromName,
                kind: Composer.display(p.atmosphere),
                text: p.text,
                symbolName: p.symbolName ?? p.photoSymbolName,
                moodHex: p.moodColorHex,
                emoji: p.emojiSequence,
                zodiac: p.zodiacSign,
                hasPhoto: p.photoData != nil,
                hasVoice: p.voiceData != nil,
                secret: p.secretUntilTapped,
                date: wink.date
            )
        }
        let peers: [WatchPeer] = manager.availablePeers.map { peer in
            WatchPeer(id: peer.id, name: peer.winkName, locked: manager.isLocked(peer))
        }
        WatchLink.shared.push(WatchState(
            name: displayName,
            discoverable: manager.isDiscoverable,
            peers: peers,
            winks: winks
        ))
    }

    /// Everything the watch asks for goes through the phone's own rules:
    /// `send` runs the content filter and the one-shot lock, and report and
    /// block land in the same ModerationStore as a tap on the phone.
    private func handleWatch(_ command: WatchCommand) {
        let wink = command.winkID.flatMap { id in moderation.received.first { $0.id == id } }

        switch command.kind {
        case .refresh:
            break
        case .ghost:
            manager.toggleGhostMode()
        case .send, .reply:
            var target: WinkPeer?
            if let id = command.peerID {
                target = manager.availablePeers.first { $0.id == id }
            } else if let wink {
                target = manager.availablePeers.first { $0.winkName == wink.fromName }
            }
            guard let peer = target else {
                manager.delivery = .failed(wink?.fromName ?? "them")
                break
            }
            let card = WinkMessage(
                text: command.text ?? "",
                pack: "Watch",
                atmosphere: Composer.symbols.atmosphere,
                ink: Composer.symbols.ink,
                symbolName: command.symbolName ?? WinkSymbol.send
            )
            send(card, to: peer, kind: command.kind == .reply ? .reply : .wink)
        case .remove:
            if let wink { moderation.remove(wink) }
        case .report:
            if let wink {
                _ = moderation.report(
                    name: wink.fromName,
                    reason: .other,
                    details: "Reported from Apple Watch",
                    evidence: wink.payload.text
                )
                moderation.remove(wink)
            }
        case .block:
            if let wink {
                if let peer = manager.availablePeers.first(where: { $0.winkName == wink.fromName }) {
                    manager.block(peer)
                } else {
                    moderation.block(wink.fromName)
                }
                moderation.remove(wink)
            }
        }
        pushWatchState()
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
    var onDone: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @State private var nameError: String?

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
    var onCancel: () -> Void = {}

    var body: some View {
        NavigationStack {
            Group {
            if peers.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "antenna.radiowaves.left.and.right.slash")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(.secondary)
                    Text("No one nearby yet.")
                        .font(WinkFont.body(15))
                    Text("WINK finds people on the same Wi Fi or within Bluetooth range. Keep this open and it keeps looking.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
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
                                Text("One shot. Waiting on a wink back")
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
            }
            }
            .navigationTitle("Send to")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
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
    var waitingCount: Int = 0

    @State private var replyIndex = 0
    @State private var opened = false
    @State private var letterOpened = false
    @State private var showFullPhoto = false
    @StateObject private var voice = VoiceRecorder()

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

                if waitingCount > 0 {
                    Text(waitingCount == 1 ? "1 MORE WAITING" : "\(waitingCount) MORE WAITING")
                        .font(WinkFont.label(10))
                        .tracking(1.4)
                        .foregroundStyle(.white.opacity(0.5))
                        .accessibilityLabel(
                            waitingCount == 1
                                ? "One more wink waiting behind this one"
                                : "\(waitingCount) more winks waiting behind this one"
                        )
                }

                // The card arrives as a sealed envelope: flap opens, the folded
                // letter rises out, the fold falls away. Once it is flat the
                // real card takes over so every tap on it still works.
                EnvelopeReveal(
                    tint: payload.asMessage.ink.accent,
                    senderName: payload.fromName,
                    onOpened: { letterOpened = true }
                ) {
                    WinkCardView(
                        message: payload.asMessage,
                        fromName: payload.fromName,
                        secretEnabled: true,
                        onPlayVoice: payload.voiceData == nil ? nil : {
                            if voice.isPlaying {
                                voice.stopPlayback()
                            } else if let data = payload.voiceData {
                                voice.play(data)
                            }
                        },
                        isPlayingVoice: voice.isPlaying
                    )
                }
                .aspectRatio(InviteCard.aspectRatio, contentMode: .fit)
                .padding(.horizontal, 36)
                .onTapGesture {
                    guard letterOpened else { return }
                    if payload.photoData != nil {
                        showFullPhoto = true
                    } else if let url = payload.asMessage.linkURL {
                        UIApplication.shared.open(url)
                    }
                }

                // Nothing to act on until the letter is actually open.
                Group {
                if payload.voiceData != nil, !voice.playThroughSilentSwitch {
                    Button {
                        voice.playThroughSilentSwitch = true
                    } label: {
                        Label("Play even if muted", systemImage: "speaker.slash.fill")
                            .font(WinkFont.label(11))
                            .tracking(1)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .accessibilityHint("By default a voice wink stays silent when your ringer switch is off")
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

                Button(waitingCount > 0 ? "NEXT" : "CLOSE", action: onClose)
                    .font(WinkFont.label(13))
                    .tracking(1.6)
                    .foregroundStyle(.white)
                    .padding(.bottom, 8)
                }
                .opacity(letterOpened ? 1 : 0)
                .allowsHitTesting(letterOpened)
                .animation(.easeOut(duration: 0.28), value: letterOpened)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                opened = true
            }
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
        .onDisappear { voice.reset() }
        .fullScreenCover(isPresented: $showFullPhoto) {
            FullPhotoView(data: payload.photoData) { showFullPhoto = false }
        }
    }
}

/// Photos are never shown full-bleed on receipt — the card is a preview and the
/// recipient decides whether to open it.
struct FullPhotoView: View {
    let data: Data?
    var onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel("Photo wink, full screen")
            }
            VStack {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(18)
                    }
                    .accessibilityLabel("Close the photo")
                }
                Spacer()
            }
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

