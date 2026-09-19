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
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 34, height: 34)
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

            composerStrip

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

    private var composerStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Composer.allCases) { item in
                    let selected = item == composer
                    Button {
                        guard !selected else { return }
                        selectedAtmosphere = item.atmosphere
                        selectedDeckIndex = 0
                        selectedCardIndex = 0
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: item.icon)
                                .font(.system(size: 17, weight: .semibold))
                            Text(item.rawValue.uppercased())
                                .font(WinkFont.label(9))
                                .tracking(0.7)
                                .lineLimit(1)
                                .minimumScaleFactor(0.65)
                        }
                        .foregroundStyle(selected ? WinkColor.night : .white.opacity(0.62))
                        .frame(width: 66, height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(selected ? WinkColor.volt : Color.white.opacity(0.06))
                        )
                    }
                    .accessibilityLabel(item.rawValue)
                    .accessibilityValue(item.line)
                    .accessibilityAddTraits(selected ? [.isSelected] : [])
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 56)
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
                            .font(WinkFont.label(12))
                            .tracking(1.1)
                            .foregroundStyle(selectedDeckIndex == index ? WinkColor.volt : .white.opacity(0.4))
                    }
                    .accessibilityAddTraits(selectedDeckIndex == index ? [.isSelected] : [])
                }
            }
            .padding(.horizontal, 6)
        }
        .frame(height: 22)
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
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(unreadCount > 0 ? WinkColor.volt : .white.opacity(0.5))
                .frame(width: 54, height: 46)

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
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(on ? WinkColor.volt : .white.opacity(0.5))
            .frame(width: 54, height: 46)
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
