import MapKit
import PencilKit
import SwiftUI

struct WinkCardView: View {
    let message: WinkMessage
    var fromName: String? = nil
    var liveDrawing: Bool = false
    var hidesCaption: Bool = false

    var body: some View {
        Group {
            if message.atmosphere == "Links" {
                linkInvite
            } else if message.symbolName != nil {
                symbolInvite
            } else {
                splitInvite
            }
        }
        .aspectRatio(InviteCard.aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: InviteCard.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: InviteCard.cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.32), radius: 26, y: 16)
    }

    /// Caption on top, symbol underneath — both centered. Invites-sized portrait card.
    private var symbolInvite: some View {
        GeometryReader { geo in
            let symbolSize = min(geo.size.width, geo.size.height) * 0.34

            ZStack {
                LinearGradient(
                    colors: message.ink.heroColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

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
                LinearGradient(
                    colors: message.ink.heroColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

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
            LinearGradient(
                colors: message.ink.heroColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

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
        guard let drawing = try? PKDrawing(data: data) else { return nil }
        let bounds = drawing.bounds.insetBy(dx: -24, dy: -24)
        let renderBounds = bounds.isNull || bounds.isEmpty ? CGRect(x: 0, y: 0, width: 400, height: 280) : bounds
        return drawing.image(from: renderBounds, scale: 3)
    }
}

private extension CardInk {
    var heroColors: [Color] {
        switch self {
        case .volt: [WinkColor.volt, Color(red: 0.99, green: 0.78, blue: 0.18)]
        case .ink: [Color(red: 0.10, green: 0.10, blue: 0.11), Color(red: 0.18, green: 0.18, blue: 0.20)]
        case .gold: [Color(red: 0.18, green: 0.14, blue: 0.06), Color(red: 0.42, green: 0.32, blue: 0.10)]
        case .field: [WinkColor.field, Color(red: 0.12, green: 0.28, blue: 0.16)]
        case .wine: [WinkColor.wine, Color(red: 0.42, green: 0.12, blue: 0.14)]
        case .ember: [Color(red: 0.18, green: 0.07, blue: 0.04), Color(red: 0.55, green: 0.22, blue: 0.08)]
        case .ice: [Color(red: 0.06, green: 0.16, blue: 0.18), Color(red: 0.12, green: 0.32, blue: 0.34)]
        case .kraft: [WinkColor.kraft, Color(red: 0.22, green: 0.20, blue: 0.16)]
        }
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
