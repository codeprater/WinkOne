import SwiftUI
import UIKit

struct LinkStudio: View {
    @Binding var linkText: String
    var fromName: String
    var placeName: String? = nil

    @FocusState private var fieldFocused: Bool
    @State private var pasteHint = false

    private var current: WinkMessage {
        WinkMessage(
            text: linkText,
            pack: "Links",
            atmosphere: "Links",
            ink: .ice,
            symbolName: "link",
            placeName: placeName
        )
    }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                WinkCardView(message: current, fromName: fromName, hidesCaption: true)
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    Color.clear.frame(height: 56)
                    Spacer(minLength: 8)
                    TextField("Long press to paste a link", text: $linkText, axis: .vertical)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(WinkColor.volt)
                        .tint(WinkColor.ice)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .lineLimit(3)
                        .focused($fieldFocused)
                        .padding(.horizontal, 36)
                        .onLongPressGesture(minimumDuration: 0.35) {
                            pasteLink()
                        }
                        .onChange(of: linkText) { _, newValue in
                            if newValue.count > 240 {
                                linkText = String(newValue.prefix(240))
                            }
                        }
                    Spacer(minLength: 120)
                }
            }
            .padding(.horizontal, 48)
            .contextMenu {
                Button("Paste Link") { pasteLink() }
                if !linkText.isEmpty {
                    Button("Copy") { UIPasteboard.general.string = linkText }
                    Button("Clear", role: .destructive) { linkText = "" }
                }
            }

            Text(pasteHint ? "Pasted." : "Long press the field to paste any link")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    private func pasteLink() {
        if let pasted = LinkPaste.fromPasteboard() {
            linkText = pasted
            pasteHint = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                pasteHint = false
            }
        } else {
            fieldFocused = true
        }
    }
}
