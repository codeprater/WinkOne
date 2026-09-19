import SwiftUI
import UIKit

/// The arrival animation for a received wink.
///
/// A sealed envelope drops in, the flap swings open, the folded letter rises
/// out, and the fold falls away to become the card. Four short beats — the
/// whole thing is under 1.6s, because an animation you sit through twice is an
/// animation you start resenting.
///
/// Reduce Motion skips straight to the card; VoiceOver is told the card is
/// there the moment it exists, not when the choreography finishes.
struct EnvelopeReveal<Card: View>: View {
    /// The colours come from the sender's atmosphere so the envelope already
    /// hints at what is inside.
    var tint: Color = WinkColor.volt
    var paper: Color = Color(winkHex: "F6F1E4")
    var senderName: String
    var onOpened: () -> Void = {}

    @ViewBuilder var card: () -> Card

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var phase: Phase = .sealed
    @State private var flap: Double = 0        // 0 sealed … 1 fully open
    @State private var lift: CGFloat = 0       // 0 inside … 1 clear of the envelope
    @State private var unfold: CGFloat = 0     // 0 folded … 1 flat
    @State private var envelopeOpacity: Double = 1
    @State private var seal: CGFloat = 1

    private enum Phase { case sealed, opening, rising, unfolding, done }

    private var isDone: Bool { phase == .done }

    var body: some View {
        ZStack {
            if isDone {
                card()
                    .transition(.identity)
            } else {
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    // The envelope is a landscape pocket roughly two thirds the
                    // width of the finished card, centred.
                    let envW = w * 0.82
                    let envH = envW * 0.62

                    ZStack {
                        // The card, folded into thirds inside the envelope.
                        card()
                            .scaleEffect(x: 1, y: max(0.001, 0.34 + 0.66 * unfold), anchor: .top)
                            .overlay { creases }
                            .rotation3DEffect(
                                .degrees((1 - Double(unfold)) * 26),
                                axis: (x: 1, y: 0, z: 0),
                                anchor: .top,
                                perspective: 0.45
                            )
                            .frame(width: w * (0.66 + 0.34 * unfold))
                            .offset(y: (1 - lift) * (h * 0.30))
                            .opacity(lift > 0.02 ? 1 : 0)
                            .zIndex(unfold > 0.35 ? 2 : 0)

                        envelope(width: envW, height: envH)
                            .opacity(envelopeOpacity)
                            .zIndex(1)
                    }
                    .frame(width: w, height: h)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Wink from \(senderName)")
        .onAppear(perform: run)
    }

    // MARK: - Envelope

    private func envelope(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            // Pocket.
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [paper, paper.opacity(0.86)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(tint.opacity(0.35), lineWidth: 1)
                }
                .overlay(alignment: .bottom) {
                    // The two front folds, drawn as a shallow V.
                    FrontFold()
                        .stroke(tint.opacity(0.22), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.45), radius: 22, y: 14)

            // Wax seal — shrinks away as the flap lets go.
            Circle()
                .fill(tint)
                .frame(width: 30, height: 30)
                .overlay {
                    Text("W")
                        .font(WinkFont.brand(14))
                        .foregroundStyle(WinkColor.night)
                }
                .scaleEffect(seal)
                .opacity(seal)

            // Flap, hinged on the top edge.
            Flap()
                .fill(
                    LinearGradient(
                        colors: [paper.opacity(0.98), paper.opacity(0.82)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay { Flap().stroke(tint.opacity(0.3), lineWidth: 1) }
                .frame(width: width, height: height * 0.62)
                .rotation3DEffect(
                    .degrees(-168 * flap),
                    axis: (x: 1, y: 0, z: 0),
                    anchor: .top,
                    perspective: 0.55
                )
                .frame(height: height, alignment: .top)
                .zIndex(flap > 0.5 ? -1 : 1)
        }
        .frame(width: width, height: height)
    }

    /// The two horizontal fold lines, fading out as the letter flattens.
    private var creases: some View {
        GeometryReader { geo in
            let h = geo.size.height
            ZStack {
                Rectangle()
                    .fill(Color.black.opacity(0.16))
                    .frame(height: 1)
                    .position(x: geo.size.width / 2, y: h / 3)
                Rectangle()
                    .fill(Color.black.opacity(0.16))
                    .frame(height: 1)
                    .position(x: geo.size.width / 2, y: h * 2 / 3)
            }
            .opacity(Double(1 - unfold))
        }
        .allowsHitTesting(false)
    }

    // MARK: - Choreography

    private func run() {
        guard !reduceMotion else {
            phase = .done
            unfold = 1
            lift = 1
            onOpened()
            return
        }

        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()

        // 1. Seal breaks, flap swings open.
        withAnimation(.easeOut(duration: 0.18)) { seal = 0 }
        withAnimation(.easeInOut(duration: 0.42)) {
            flap = 1
            phase = .opening
        }

        // 2. Letter rises out.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(360))
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            withAnimation(.spring(response: 0.52, dampingFraction: 0.82)) {
                lift = 1
                phase = .rising
            }

            // 3. Fold falls open, envelope bows out.
            try? await Task.sleep(for: .milliseconds(380))
            withAnimation(.spring(response: 0.58, dampingFraction: 0.78)) {
                unfold = 1
                phase = .unfolding
            }
            withAnimation(.easeOut(duration: 0.32)) { envelopeOpacity = 0 }

            // 4. Hand off to the real card so every gesture on it works.
            try? await Task.sleep(for: .milliseconds(520))
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            phase = .done
            onOpened()
        }
    }
}

// MARK: - Shapes

private struct Flap: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct FrontFold: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return p
    }
}
