import SwiftUI

/// The tool bar, collapsed to a pill when the radar has the floor.
///
/// Expanded it carries the composer strip, the pack row and the actions.
/// Collapsed it is a single row — inbox, send, and a grip to bring it back.
struct WinkDock: View {
    @Binding var isExpanded: Bool
    /// Set by the idle timer in ContentView. Hidden leaves only a thin grab
    /// tab, so the radar gets the whole screen when nobody is composing.
    @Binding var isHidden: Bool
    @Binding var selectedAtmosphere: String
    @Binding var selectedDeckIndex: Int
    @Binding var selectedCardIndex: Int
    @Binding var secretUntilTapped: Bool

    var visibleDecks: [WinkDeck]
    var unreadCount: Int
    var locationSharing: Bool
    var locationLabel: String
    var onToggleLocation: () -> Void
    var onSend: () -> Void
    var onOpenInbox: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showCardTypes = false

    private var composer: Composer { Composer(atmosphere: selectedAtmosphere) }

    var body: some View {
        VStack(spacing: 0) {
            if isHidden {
                grabTab
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if isExpanded {
                expanded
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                collapsed
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? .none : .spring(response: 0.34, dampingFraction: 0.85), value: isExpanded)
        .animation(reduceMotion ? .none : .spring(response: 0.38, dampingFraction: 0.86), value: isHidden)
        .sheet(isPresented: $showCardTypes) {
            CardTypePicker(current: composer) { picked in
                showCardTypes = false
                guard picked != composer else { return }
                selectedAtmosphere = picked.atmosphere
                selectedDeckIndex = 0
                selectedCardIndex = 0
            }
        }
        .gesture(
            DragGesture(minimumDistance: 14)
                .onEnded { value in
                    if value.translation.height < -14 {
                        isHidden = false
                        setExpanded(true)
                    } else if value.translation.height > 14 {
                        if isExpanded { setExpanded(false) } else { isHidden = true }
                    }
                }
        )
    }

    // MARK: Hidden

    /// What is left when the dock steps out of the way: a tap target wide
    /// enough to find, short enough to forget about.
    private var grabTab: some View {
        Button {
            isHidden = false
            setExpanded(true)
        } label: {
            HStack(spacing: 8) {
                Capsule()
                    .fill(.white.opacity(0.35))
                    .frame(width: 46, height: 5)
                if unreadCount > 0 {
                    Circle()
                        .fill(WinkColor.volt)
                        .frame(width: 7, height: 7)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .opacity(0.85)
            )
            .contentShape(Rectangle())
        }
        .padding(.bottom, 10)
        .accessibilityLabel("Show the tools")
        .accessibilityHint("The tools hide themselves when you are not using them")
    }

    // MARK: Collapsed

    private var collapsed: some View {
        HStack(spacing: 18) {
            inboxButton

            Button(action: onSend) {
                HStack(spacing: 7) {
                    Image(systemName: WinkSymbol.send)
                        .font(.system(size: 14, weight: .bold))
                    Text("SEND")
                        .font(WinkFont.label(12))
                        .tracking(1.1)
                        .fixedSize()
                }
                .foregroundStyle(WinkColor.night)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Capsule().fill(WinkColor.volt))
            }
            .accessibilityLabel("Send this wink")

            Button {
                setExpanded(true)
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Show the tools")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(dockSurface)
        .padding(.bottom, 12)
    }

    // MARK: Expanded

    private var expanded: some View {
        VStack(spacing: 12) {
            HStack {
                Capsule()
                    .fill(.white.opacity(0.22))
                    .frame(width: 38, height: 4)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { setExpanded(false) }
            .accessibilityLabel("Hide the tools")
            .accessibilityAddTraits(.isButton)

            cardTypeButton

            if composer.isDeck, !visibleDecks.isEmpty {
                packStrip
            }

            actionStrip
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 14)
        .background(dockSurface)
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
    }

    /// One clear button that says what you are making and lets you change it.
    /// Replaces a strip of thirteen tiny tiles that scrolled off the edge.
    private var cardTypeButton: some View {
        Button {
            showCardTypes = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: composer.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(WinkColor.night)
                    .frame(width: 38, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(WinkColor.volt)
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(composer.displayName)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(composer.line)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                HStack(spacing: 4) {
                    Text("Change")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(WinkColor.volt)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(minHeight: 54)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.07))
            )
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Card type, \(composer.displayName)")
        .accessibilityHint("Choose a different kind of card to make")
    }

    private var packStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(Array(visibleDecks.enumerated()), id: \.element.id) { index, deck in
                    Button {
                        selectedDeckIndex = index
                        selectedCardIndex = 0
                    } label: {
                        Text(deck.name.uppercased())
                            .font(WinkFont.label(13))
                            .tracking(1.1)
                            .foregroundStyle(selectedDeckIndex == index ? WinkColor.night : .white.opacity(0.75))
                            .padding(.horizontal, 12)
                            .frame(minHeight: 32)
                            .background(
                                Capsule().fill(selectedDeckIndex == index ? WinkColor.volt : Color.white.opacity(0.07))
                            )
                    }
                    .accessibilityAddTraits(selectedDeckIndex == index ? [.isSelected] : [])
                }
            }
            .padding(.horizontal, 6)
        }
        .frame(height: 34)
    }

    private var actionStrip: some View {
        HStack(spacing: 10) {
            inboxButton

            dockTool(
                icon: locationSharing ? "mappin.circle.fill" : "mappin",
                title: locationLabel,
                on: locationSharing,
                action: onToggleLocation
            )
            .accessibilityLabel(locationSharing ? "Location on" : "Add location")

            dockTool(
                icon: secretUntilTapped ? "eye.slash.fill" : "eye",
                title: "Secret",
                on: secretUntilTapped,
                action: {
                    secretUntilTapped.toggle()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            )
            .accessibilityLabel("Secret Wink")
            .accessibilityValue(secretUntilTapped ? "On" : "Off")
            .accessibilityHint("Hides the card until they tap to reveal it")

            Button(action: onSend) {
                HStack(spacing: 8) {
                    Image(systemName: WinkSymbol.send)
                        .font(.system(size: 15, weight: .bold))
                    Text("SEND")
                        .font(WinkFont.label(13))
                        .tracking(1.2)
                        .fixedSize()
                }
                .foregroundStyle(WinkColor.night)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(WinkColor.volt))
            }
            .accessibilityLabel("Send this wink")
        }
    }

    // MARK: Pieces

    private var inboxButton: some View {
        Button(action: onOpenInbox) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 4) {
                    Image(systemName: WinkSymbol.inbox)
                        .font(.system(size: 17, weight: .semibold))
                    Text("Inbox")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(unreadCount > 0 ? WinkColor.volt : .white.opacity(0.7))
                .frame(width: 58, height: 48)

                if unreadCount > 0 {
                    Text("\(min(unreadCount, 99))")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(WinkColor.night)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(WinkColor.volt))
                        .offset(x: 2, y: -2)
                }
            }
        }
        .accessibilityLabel("Inbox")
        .accessibilityValue(unreadCount == 0 ? "Empty" : "\(unreadCount) winks")
    }

    private func dockTool(
        icon: String,
        title: String,
        on: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .symbolEffect(.bounce, value: on)
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(on ? WinkColor.volt : .white.opacity(0.7))
            .frame(width: 58, height: 48)
        }
    }

    private var dockSurface: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.45), radius: 20, y: 8)
    }

    private func setExpanded(_ value: Bool) {
        isExpanded = value
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// MARK: - Card type picker

/// Every kind of card, as big labelled tiles in two plain groups: the ones you
/// build yourself and the ready-made packs you swipe through.
struct CardTypePicker: View {
    var current: Composer
    var onPick: (Composer) -> Void

    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 12)]
    private let makers = Composer.allCases.filter { $0.isStudio }
    private let packs = Composer.allCases.filter { $0.isDeck }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    section(
                        "Make your own",
                        "Your card on top, every tool right under it.",
                        makers
                    )
                    section(
                        "Ready-made packs",
                        "Swipe through cards that are ready to send.",
                        packs
                    )
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
            }
            .background(WinkColor.night.ignoresSafeArea())
            .navigationTitle("Choose a card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(WinkColor.volt)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }

    private func section(_ title: String, _ subtitle: String, _ items: [Composer]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
            }
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(items) { item in
                    tile(item)
                }
            }
        }
    }

    private func tile(_ item: Composer) -> some View {
        let selected = item == current
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onPick(item)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: item.icon)
                    .font(.system(size: 26, weight: .semibold))
                    .frame(height: 30)
                Text(item.displayName)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(item.line)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .opacity(0.75)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(selected ? WinkColor.night : .white)
            .padding(.horizontal, 8)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 124)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selected ? WinkColor.volt : Color.white.opacity(0.08))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.displayName)
        .accessibilityValue(item.line)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
