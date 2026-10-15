import Combine
import SwiftUI
import UIKit

#if canImport(FoundationModels)
import FoundationModels
#endif

#if canImport(ImagePlayground)
import ImagePlayground
#endif

// MARK: - What this device can actually do
//
// None of this is assumed. Apple Intelligence needs an A17 Pro, an M series
// chip, or newer, and the user has to have turned it on. Everything below
// checks first and the UI simply does not offer what the device cannot do,
// rather than offering it and failing.

enum WinkAI {
    /// True when the on device language model is present and switched on.
    static var writesLines: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        #endif
        return false
    }

    /// True when Image Playground can run here.
    static var makesImages: Bool {
        #if canImport(ImagePlayground)
        if #available(iOS 18.4, *) {
            return ImagePlaygroundViewController.isAvailable
        }
        #endif
        return false
    }

    /// Genmoji rides in on the keyboard, so the test is whether the text system
    /// will accept an adaptive image glyph.
    static var acceptsGenmoji: Bool {
        if #available(iOS 18.0, *) { return true }
        return false
    }

    /// Shown once, in plain words, where a feature is missing.
    static let unavailableLine = "Apple Intelligence is off or this device cannot run it."
}

// MARK: - Writing Tools

extension View {
    /// Proofread, rewrite and tone controls on a caption field. Free on iOS 18
    /// and up, and a no op below it.
    @ViewBuilder
    func winkWritingTools(full: Bool = true) -> some View {
        if #available(iOS 18.0, *) {
            self.writingToolsBehavior(full ? .complete : .limited)
        } else {
            self
        }
    }
}

// MARK: - Line suggestions

/// Asks the on device model for a few short lines that fit the card being
/// composed. Nothing leaves the phone.
@MainActor
final class WinkLineSuggester: ObservableObject {
    @Published private(set) var lines: [String] = []
    @Published private(set) var isWorking = false
    @Published private(set) var note: String?

    func suggest(for composerName: String, seed: String) {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard WinkAI.writesLines else {
                note = WinkAI.unavailableLine
                return
            }
            isWorking = true
            note = nil
            Task { @MainActor in
                defer { isWorking = false }
                let instructions = """
                You write one line messages for a card someone hands to a \
                stranger nearby. Keep each line under eight words. Be warm, \
                plain and a little funny. No hashtags, no emoji, no quotation \
                marks, no dashes of any kind.
                """
                let session = LanguageModelSession(instructions: instructions)
                let ask = seed.isEmpty
                    ? "Write four lines for a \(composerName) card."
                    : "Write four lines for a \(composerName) card about: \(seed)"
                do {
                    let reply = try await session.respond(to: ask)
                    self.lines = Self.tidy(reply.content)
                } catch {
                    self.note = "Could not write anything just now."
                }
            }
            return
        }
        #endif
        note = WinkAI.unavailableLine
    }

    func clear() {
        lines = []
        note = nil
    }

    private static func tidy(_ raw: String) -> [String] {
        let cleaned = raw
            .split(separator: "\n")
            .map { line in
                line
                    .trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: #"^[\-\*\d\.\)\s]+"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: "\"", with: "")
                    .replacingOccurrences(of: "—", with: " ")
                    .replacingOccurrences(of: "–", with: " ")
                    .replacingOccurrences(of: "-", with: " ")
                    .trimmingCharacters(in: .whitespaces)
            }
            .filter { !$0.isEmpty && $0.count <= 60 }
        let capped = Array(cleaned.prefix(4))
        return capped
    }
}

/// A row of suggested lines plus the button that asks for them. Renders
/// nothing at all on a device that cannot run the model.
struct SuggestLinesRow: View {
    let composerName: String
    var seed: String = ""
    @Binding var target: String

    @StateObject private var suggester = WinkLineSuggester()

    var body: some View {
        if WinkAI.writesLines {
            VStack(spacing: 8) {
                Button {
                    suggester.suggest(for: composerName, seed: seed)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "apple.intelligence")
                            .font(.system(size: 13, weight: .semibold))
                        Text(suggester.isWorking ? "Writing" : "Write me one")
                            .font(WinkFont.label(13))
                            .tracking(1)
                    }
                    .foregroundStyle(WinkColor.volt)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 40)
                    .background(Capsule().fill(Color.white.opacity(0.09)))
                }
                .disabled(suggester.isWorking)
                .accessibilityLabel("Suggest a line with Apple Intelligence")

                if let note = suggester.note {
                    Text(note)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                }

                if !suggester.lines.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(suggester.lines, id: \.self) { line in
                                Button {
                                    target = line
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    Text(line)
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(Color.white.opacity(0.1))
                                        )
                                }
                            }
                        }
                        .padding(.horizontal, 22)
                    }
                    .frame(height: 40)
                }
            }
        }
    }
}
