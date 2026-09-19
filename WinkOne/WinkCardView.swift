import MapKit
import PencilKit
import SwiftUI
import UIKit

struct WinkCardView: View {
    let message: WinkMessage
    var fromName: String? = nil
    var liveDrawing: Bool = false
    var hidesCaption: Bool = false

    /// Waveform samples captured while recording, so a Voice Wink shows its own
    /// shape rather than a generic one. Empty on a received card falls back to a
    /// synthesized shape derived from the duration.
    var bakedLevels: [CGFloat] = []

    /// Only a received card honours the Secret modifier. Composer previews and
    /// CardRenderer never veil, or you could not see what you are making.
    var secretEnabled: Bool = false

    /// Supplied by the incoming-card view. Nil while rendering to an image.
    var onPlayVoice: (() -> Void)? = nil
    var isPlayingVoice: Bool = false

    @State private var revealed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isVeiled: Bool {
        secretEnabled && message.secretUntilTapped && !revealed
    }

    var body: some View {
        Group {
            if let sign = Zodiac.named(message.zodiacSign) {
                zodiacInvite(sign)
            } else if message.moodColorHex != nil {
                moodInvite
            } else if message.emojiSequence != nil {
                emojiInvite
            } else if message.photoData != nil {
                photoInvite
            } else if message.voiceData != nil {
                voiceInvite
            } else if message.atmosphere == "Links" {
                linkInvite
            } else if message.symbolName != nil {
                symbolInvite
            } else {
                splitInvite
            }
        }
        .blur(radius: isVeiled ? 22 : 0)
        .aspectRatio(InviteCard.aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: InviteCard.cornerRadius, style: .continuous))
        .overlay { secretVeil }
        .overlay {
            RoundedRectangle(cornerRadius: InviteCard.cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.32), radius: 26, y: 16)
    }

    // MARK: - Secret modifier

    @ViewBuilder
    private var secretVeil: some View {
        if isVeiled {
            ZStack {
                Color.black.opacity(0.35)
                VStack(spacing: 10) {
                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: 30, weight: .semibold))
                    Text("TAP TO REVEAL")
                        .font(WinkFont.label(12))
                        .tracking(1.6)
                }
                .foregroundStyle(WinkColor.volt)
            }
            .clipShape(RoundedRectangle(cornerRadius: InviteCard.cornerRadius, style: .continuous))
            .contentShape(Rectangle())
            .onTapGesture { reveal() }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Hidden wink")
            .accessibilityHint("Double tap to reveal")
            .accessibilityAddTraits(.isButton)
        }
    }

    private func reveal() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        if reduceMotion {
            revealed = true
        } else {
            withAnimation(.easeOut(duration: 0.4)) { revealed = true }
        }
    }

    // MARK: - 2.0 layouts

    /// Waveform across the top half, play control centred, caption below.
    private var voiceInvite: some View {
        GeometryReader { geo in
            ZStack {
                InviteBackdrop(ink: message.ink)

                VStack(spacing: 0) {
                    cardHeader(right: "VOICE")

                    Spacer(minLength: 8)

                    WaveformView(
                        levels: displayLevels,
                        barColor: message.ink.type.opacity(0.85),
                        animates: false
                    )
                    .frame(height: geo.size.height * 0.18)
                    .padding(.horizontal, 26)

                    Spacer(minLength: 10)

                    Button {
                        onPlayVoice?()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(message.ink.type.opacity(0.14))
                                .frame(width: geo.size.width * 0.28, height: geo.size.width * 0.28)
                            Image(systemName: isPlayingVoice ? "stop.fill" : "play.fill")
                                .font(.system(size: geo.size.width * 0.11, weight: .bold))
                                .foregroundStyle(message.ink.type)
                        }
                    }
                    .disabled(onPlayVoice == nil)
                    .accessibilityLabel(isPlayingVoice ? "Stop the voice wink" : "Play the voice wink")

                    if !hidesCaption, !message.text.isEmpty {
                        Text(message.text)
                            .font(.system(size: captionSize(for: geo.size.width), weight: .bold, design: .rounded))
                            .foregroundStyle(message.ink.type)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.5)
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                    }

                    Spacer(minLength: 8)

                    cardFooter(
                        extra: message.voiceDuration.map { String(format: "%.1fs", $0) }
                    )
                }
            }
        }
    }

    /// The photo fills the card; caption rides in a translucent bar at the foot.
    private var photoInvite: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Decoded once at the size on screen and cached. A raw
                // UIImage(data:) here re-decoded the whole JPEG every render.
                if let data = message.photoData,
                   let image = DecodedImageCache.shared.image(
                       for: data,
                       maxPixel: max(geo.size.width, geo.size.height) * 2
                   ) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    InviteBackdrop(ink: message.ink)
                    Image(systemName: "photo")
                        .font(.system(size: geo.size.width * 0.2))
                        .foregroundStyle(message.ink.type.opacity(0.5))
                        .frame(maxHeight: .infinity)
                }

                if let symbol = message.photoSymbolName {
                    Image(systemName: symbol)
                        .font(.system(size: geo.size.width * 0.16, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.45), radius: 8, y: 3)
                        .padding(18)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }

                VStack(spacing: 6) {
                    if !hidesCaption, let caption = message.photoCaption, !caption.isEmpty {
                        Text(caption)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.6)
                    }
                    HStack(spacing: 8) {
                        Text("WINK")
                            .font(WinkFont.brand(11))
                            .tracking(2.2)
                        if let place = message.placeName, !place.isEmpty {
                            Text("· \(place)")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                        if let fromName, !fromName.isEmpty {
                            Text("· From \(fromName)")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                    }
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(.black.opacity(0.42))
            }
        }
    }

    /// The whole card is the color. One word, centred.
    private var moodInvite: some View {
        GeometryReader { geo in
            let hex = message.moodColorHex ?? MoodPalette.defaultHex
            let light = Color.winkIsLight(hex: hex)
            let ink: Color = light ? WinkColor.night : WinkColor.bone

            ZStack {
                Color(winkHex: hex)

                VStack(spacing: 0) {
                    HStack {
                        Text("WINK")
                            .font(WinkFont.brand(12))
                            .tracking(2.6)
                            .fixedSize()
                        Spacer(minLength: 8)
                        Text("MOOD")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .tracking(1.1)
                            .fixedSize()
                    }
                    .foregroundStyle(ink.opacity(0.6))
                    .padding(.horizontal, 22)
                    .padding(.top, 18)

                    Spacer()

                    Text((message.moodWord ?? "").uppercased())
                        .font(WinkFont.shout(geo.size.width * 0.17))
                        .tracking(1.5)
                        .foregroundStyle(ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.4)
                        .padding(.horizontal, 24)

                    Spacer()

                    VStack(spacing: 6) {
                        if let place = message.placeName, !place.isEmpty {
                            Text(place)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        if let fromName, !fromName.isEmpty {
                            Text("From \(fromName)")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                    }
                    .foregroundStyle(ink.opacity(0.62))
                    .padding(.bottom, 18)
                }
            }
        }
    }

    /// One at 200, two side by side at 140, three in a triangle at 110.
    private var emojiInvite: some View {
        GeometryReader { geo in
            let emoji = Array(message.emojiSequence ?? "")
            let scale = geo.size.width / InviteCard.renderWidth

            ZStack {
                InviteBackdrop(ink: message.ink)

                VStack(spacing: 0) {
                    cardHeader(right: "EMOJI")
                    Spacer()
                    emojiCluster(emoji, scale: scale)
                    Spacer()
                    cardFooter(extra: nil)
                }
            }
        }
    }

    @ViewBuilder
    private func emojiCluster(_ emoji: [Character], scale: CGFloat) -> some View {
        switch emoji.count {
        case 1:
            Text(String(emoji[0])).font(.system(size: 200 * scale))
        case 2:
            HStack(spacing: 18 * scale) {
                Text(String(emoji[0])).font(.system(size: 140 * scale))
                Text(String(emoji[1])).font(.system(size: 140 * scale))
            }
        case 3:
            VStack(spacing: 6 * scale) {
                Text(String(emoji[0])).font(.system(size: 110 * scale))
                HStack(spacing: 16 * scale) {
                    Text(String(emoji[1])).font(.system(size: 110 * scale))
                    Text(String(emoji[2])).font(.system(size: 110 * scale))
                }
            }
        default:
            Image(systemName: "face.smiling")
                .font(.system(size: 90 * scale))
                .foregroundStyle(message.ink.type.opacity(0.4))
        }
    }

    // MARK: - Zodiac

    /// The sign is the card. Glyph over its own three-stop gradient, the
    /// sender's line underneath, element and dates as the quiet footnote.
    private func zodiacInvite(_ sign: Zodiac) -> some View {
        GeometryReader { geo in
            let scale = geo.size.width / InviteCard.renderWidth
            let ink = sign.ink
            let caption = message.text.trimmingCharacters(in: .whitespacesAndNewlines)

            ZStack {
                LinearGradient(
                    colors: sign.gradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // A soft halo behind the glyph so the gradient has a centre.
                RadialGradient(
                    colors: [sign.accent.opacity(0.35), .clear],
                    center: .center,
                    startRadius: 4 * scale,
                    endRadius: 190 * scale
                )
                .blendMode(.screen)

                VStack(spacing: 0) {
                    HStack {
                        Text("WINK")
                            .font(WinkFont.brand(12))
                            .tracking(2.6)
                            .fixedSize()
                        Spacer(minLength: 8)
                        Text(sign.rawValue.uppercased())
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .tracking(1.1)
                            .fixedSize()
                    }
                    .foregroundStyle(ink.opacity(0.7))
                    .padding(.horizontal, 22)
                    .padding(.top, 18)

                    Spacer(minLength: 0)

                    Image(systemName: sign.symbol)
                        .font(.system(size: 132 * scale, weight: .light))
                        .foregroundStyle(ink)
                        .shadow(color: .black.opacity(0.25), radius: 18 * scale, y: 6 * scale)
                        .accessibilityHidden(true)

                    Text(caption.isEmpty ? sign.line : caption)
                        .font(WinkFont.shout(geo.size.width * 0.085))
                        .foregroundStyle(ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.5)
                        .padding(.horizontal, 26)
                        .padding(.top, 18 * scale)

                    Text("\(sign.element.uppercased())  ·  \(sign.dates)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(ink.opacity(0.62))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    Spacer(minLength: 0)

                    VStack(spacing: 6) {
                        if let place = message.placeName, !place.isEmpty {
                            Text(place)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        if let fromName, !fromName.isEmpty {
                            Text("From \(fromName)")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                    }
                    .foregroundStyle(ink.opacity(0.62))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 18)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(sign.rawValue) wink")
            .accessibilityValue(caption.isEmpty ? sign.line : caption)
        }
    }

    // MARK: - Shared chrome

    private func cardHeader(right: String) -> some View {
        HStack {
            Text("WINK")
                .font(WinkFont.brand(12))
                .tracking(2.6)
                .fixedSize()
            Spacer(minLength: 8)
            Text(right)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .tracking(1.1)
                .fixedSize()
        }
        .foregroundStyle(message.ink.accent)
        .padding(.horizontal, 22)
        .padding(.top, 18)
    }

    private func cardFooter(extra: String?) -> some View {
        VStack(spacing: 6) {
            if let extra {
                Text(extra)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            if let place = message.placeName, !place.isEmpty {
                Text(place)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            if let fromName, !fromName.isEmpty {
                Text("From \(fromName)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
        }
        .foregroundStyle(message.ink.accent.opacity(0.9))
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.bottom, 18)
        .padding(.horizontal, 22)
    }

    /// A received card has no captured levels, so draw a stable shape from the
    /// duration instead of animating noise.
    private var displayLevels: [CGFloat] {
        if !bakedLevels.isEmpty { return bakedLevels }
        let count = 40
        return (0..<count).map { index in
            let phase = Double(index) / Double(count) * .pi * 4
            return CGFloat(0.35 + 0.45 * abs(sin(phase)))
        }
    }

    /// Caption on top, symbol underneath — both centered. Invites-sized portrait card.
    private var symbolInvite: some View {
        GeometryReader { geo in
            let symbolSize = min(geo.size.width, geo.size.height) * 0.34

            ZStack {
                InviteBackdrop(ink: message.ink)

                VStack(spacing: 0) {
                    HStack {
                        Text("WINK")
                            .font(WinkFont.brand(12))
                            .tracking(2.6)
                        Spacer()
                        Text(message.pack.uppercased())
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .tracking(1.1)
                    }
                    .foregroundStyle(message.ink.accent)
                    .padding(.horizontal, 22)
                    .padding(.top, 18)

                    Spacer(minLength: 12)

                    VStack(spacing: 22) {
                        if !hidesCaption {
                            Text(captionText)
                                .font(.system(size: captionSize(for: geo.size.width), weight: .bold, design: .rounded))
                                .foregroundStyle(message.ink.type.opacity(message.text.isEmpty ? 0.38 : 1))
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                                .minimumScaleFactor(0.45)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 24)
                        }

                        Image(systemName: message.symbolName ?? "sparkle")
                            .font(.system(size: symbolSize, weight: .regular))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(message.ink.type)
                            .frame(maxWidth: .infinity)
                    }

                    Spacer(minLength: 12)

                    VStack(spacing: 8) {
                        if let place = message.placeName, !place.isEmpty {
                            Text(place)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        if let fromName, !fromName.isEmpty {
                            Text("From \(fromName)")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                    }
                    .foregroundStyle(message.ink.accent.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 18)
                    .padding(.horizontal, 22)
                }
            }
        }
    }

    private var linkInvite: some View {
        GeometryReader { geo in
            let symbolSize = min(geo.size.width, geo.size.height) * 0.28
            let host = LinkPaste.host(from: message.text)

            ZStack {
                InviteBackdrop(ink: message.ink)

                VStack(spacing: 0) {
                    HStack {
                        Text("WINK")
                            .font(WinkFont.brand(12))
                            .tracking(2.6)
                        Spacer()
                        Text("LINK")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .tracking(1.1)
                    }
                    .foregroundStyle(message.ink.accent)
                    .padding(.horizontal, 22)
                    .padding(.top, 18)

                    Spacer(minLength: 12)

                    VStack(spacing: 18) {
                        if !hidesCaption {
                            Text(host ?? (message.text.isEmpty ? "Long press to paste a link" : message.text))
                                .font(.system(size: captionSize(for: geo.size.width), weight: .bold, design: .rounded))
                                .foregroundStyle(message.ink.type.opacity(message.text.isEmpty ? 0.4 : 1))
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                                .minimumScaleFactor(0.4)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 22)
                        }

                        Image(systemName: "link")
                            .font(.system(size: symbolSize, weight: .regular))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(message.ink.type)
                            .frame(maxWidth: .infinity)

                        if host != nil, !hidesCaption {
                            Text(message.text)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(message.ink.type.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
                                .padding(.horizontal, 22)
                        }
                    }

                    Spacer(minLength: 12)

                    VStack(spacing: 8) {
                        if let place = message.placeName, !place.isEmpty {
                            Text(place)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        if let fromName, !fromName.isEmpty {
                            Text("From \(fromName)")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                    }
                    .foregroundStyle(message.ink.accent.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 18)
                    .padding(.horizontal, 22)
                }
            }
        }
    }

    private var splitInvite: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                hero(size: geo.size)
                    .frame(height: geo.size.height * 0.58)

                details
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 22)
                    .padding(.top, 20)
                    .padding(.bottom, 18)
                    .background(Color.white)
            }
        }
    }

    private func hero(size: CGSize) -> some View {
        ZStack {
            InviteBackdrop(ink: message.ink)

            if let drawingImage {
                Image(uiImage: drawingImage)
                    .resizable()
                    .scaledToFit()
                    .padding(18)
            } else {
                Image(systemName: atmosphereIcon)
                    .font(.system(size: min(size.width, size.height) * 0.22, weight: .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(message.ink.type.opacity(0.92))
            }
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(titleText)
                .font(.system(size: titleSize, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.07, green: 0.07, blue: 0.08))
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .minimumScaleFactor(0.55)
                .fixedSize(horizontal: false, vertical: true)

            if let place = message.placeName, !place.isEmpty {
                Label(place, systemImage: "mappin")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.32, green: 0.32, blue: 0.34))
                    .lineLimit(1)
            }

            if let fromName, !fromName.isEmpty {
                Label("From \(fromName)", systemImage: "person.crop.circle")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.32, green: 0.32, blue: 0.34))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            HStack {
                Text("WINK")
                    .font(WinkFont.brand(13))
                    .tracking(2.4)
                    .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.12))
                Spacer()
                Text(message.pack.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(Color(red: 0.45, green: 0.45, blue: 0.47))
            }
        }
    }

    private var captionText: String {
        message.text.isEmpty ? "Your caption" : message.text
    }

    private func captionSize(for width: CGFloat) -> CGFloat {
        let count = captionText.count
        if count <= 8 { return width * 0.11 }
        if count <= 18 { return width * 0.08 }
        return width * 0.065
    }

    private var titleText: String {
        if !message.text.isEmpty { return message.text }
        if message.drawingData != nil { return "Handwritten WINK" }
        return message.pack
    }

    private var titleSize: CGFloat {
        let count = titleText.count
        if count <= 8 { return 34 }
        if count <= 18 { return 28 }
        return 22
    }

    private var atmosphereIcon: String {
        switch message.atmosphere {
        case "Stadium": "sportscourt.fill"
        case "Lounge": "wineglass.fill"
        case "Daily Grind": "cup.and.saucer.fill"
        case "Gen-Z": "bolt.fill"
        case "Symbols": "square.grid.2x2.fill"
        case "Handwritten": "pencil.and.scribble"
        case "Links": "link"
        default: "eye.fill"
        }
    }

    private var drawingImage: UIImage? {
        guard !liveDrawing, let data = message.drawingData, !data.isEmpty else { return nil }
        return DecodedImageCache.shared.drawing(for: data)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        WinkCardView(
            message: WinkMessage(
                text: "NO CAP",
                pack: "Symbols",
                atmosphere: "Symbols",
                ink: .volt,
                symbolName: "paperplane.fill"
            ),
            fromName: "Court"
        )
        .padding(36)
    }
}
