import SwiftUI

/// The wallpaper. Rings, crosshair and a slow sweep, with every nearby peer
/// standing somewhere on it.
///
/// Positions are decorative, not distances — MultipeerConnectivity reports no
/// range. Each peer's spot is derived deterministically from its stable id, so
/// someone stays put for the whole session instead of jumping around on every
/// redraw.
struct WinkRadar: View {
    var peers: [WinkPeer]
    var isLocked: (WinkPeer) -> Bool
    var isDiscoverable: Bool
    var onSelect: (WinkPeer) -> Void
    var onBlock: (WinkPeer) -> Void
    var onBackgroundTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("wink.radarSweep") private var sweepEnabled = true
    @State private var sweeping = false

    private let ringCount = 4

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = side / 2

            ZStack {
                WinkColor.night
                    .contentShape(Rectangle())
                    .onTapGesture { onBackgroundTap() }

                grid(radius: radius)
                    .frame(width: side, height: side)
                    .position(center)
                    .allowsHitTesting(false)

                sweep(radius: radius)
                    .opacity(sweepEnabled ? 1 : 0)
                    .frame(width: side, height: side)
                    .position(center)
                    .allowsHitTesting(false)

                ForEach(peers) { peer in
                    let spot = position(for: peer, center: center, radius: radius)
                    PeerBlip(
                        peer: peer,
                        locked: isLocked(peer),
                        onSelect: { onSelect(peer) },
                        onBlock: { onBlock(peer) }
                    )
                    .position(spot)
                }
            }
            .onAppear { sweeping = true }
        }
        .ignoresSafeArea()
    }

    // MARK: Layers

    private func grid(radius: CGFloat) -> some View {
        ZStack {
            ForEach(1...ringCount, id: \.self) { ring in
                Circle()
                    .stroke(WinkColor.volt.opacity(0.28), lineWidth: 1)
                    .frame(
                        width: radius * 2 * CGFloat(ring) / CGFloat(ringCount),
                        height: radius * 2 * CGFloat(ring) / CGFloat(ringCount)
                    )
            }
            Rectangle()
                .fill(WinkColor.volt.opacity(0.24))
                .frame(height: 1)
            Rectangle()
                .fill(WinkColor.volt.opacity(0.24))
                .frame(width: 1)
        }
    }

    private func sweep(radius: CGFloat) -> some View {
        Circle()
            .fill(
                AngularGradient(
                    gradient: Gradient(stops: [
                        .init(color: WinkColor.volt.opacity(0.00), location: 0.00),
                        .init(color: WinkColor.volt.opacity(0.06), location: 0.14),
                        .init(color: WinkColor.volt.opacity(0.22), location: 0.23),
                        .init(color: WinkColor.volt.opacity(0.00), location: 0.25),
                        .init(color: WinkColor.volt.opacity(0.00), location: 1.00)
                    ]),
                    center: .center
                )
            )
            .opacity(isDiscoverable ? 1 : 0.25)
            .rotationEffect(.degrees(sweeping && !reduceMotion ? 360 : 0))
            .animation(
                (sweeping && !reduceMotion)
                    ? .linear(duration: 6).repeatForever(autoreverses: false)
                    : nil,
                value: sweeping
            )
    }

    // MARK: Placement

    /// Angle and ring band come from the peer's stable id, so the same person
    /// lands in the same place every time the radar draws.
    private func position(for peer: WinkPeer, center: CGPoint, radius: CGFloat) -> CGPoint {
        let angle = PeerIdentity.fraction(peer.id) * 2 * .pi
        let band = PeerIdentity.fraction(peer.id, salt: 7)
        // Keep blips off the centre and off the rim.
        let distance = radius * (0.34 + 0.48 * band)
        return CGPoint(
            x: center.x + cos(angle) * distance,
            y: center.y + sin(angle) * distance
        )
    }
}

// MARK: - Blip

private struct PeerBlip: View {
    let peer: WinkPeer
    let locked: Bool
    var onSelect: () -> Void
    var onBlock: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(WinkColor.volt.opacity(0.45), lineWidth: 1)
                        .frame(width: 54, height: 54)
                        .scaleEffect(pulse && !reduceMotion ? 1.35 : 1)
                        .opacity(pulse && !reduceMotion ? 0 : 0.8)

                    Image(systemName: "figure.stand")
                        .font(.system(size: 34, weight: .regular))
                        .foregroundStyle(locked ? WinkColor.volt.opacity(0.35) : WinkColor.volt)
                }

                Text(peer.winkName)
                    .font(WinkFont.label(10))
                    .foregroundStyle(locked ? .white.opacity(0.35) : .white.opacity(0.85))
                    .lineLimit(1)
                    .frame(width: 72)

                if locked {
                    Text("ONE SHOT")
                        .font(WinkFont.label(8))
                        .tracking(0.8)
                        .foregroundStyle(WinkColor.volt.opacity(0.6))
                }
            }
        }
        .disabled(locked)
        .contextMenu {
            Button("Ignore", role: .destructive, action: onBlock)
        }
        .accessibilityLabel(peer.winkName)
        .accessibilityValue(locked ? "Waiting for them to wink back" : "On your radar")
        .accessibilityHint(locked ? "" : "Double tap to send your card")
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 2.4).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}
