import CoreText
import Foundation
import UIKit

/// Every emoji the device can actually draw, grouped the way the system
/// keyboard groups them, with search.
///
/// The ranges below are the Unicode blocks; the list is then filtered through
/// the colour emoji font, so a codepoint this iOS version cannot render never
/// shows up as a blank box. Names for search come from ICU's Any to Name
/// transform rather than a bundled keyword table, so nothing has to be kept in
/// step with new Unicode revisions.
struct EmojiGroup: Identifiable, Hashable {
    let name: String
    let icon: String
    let emoji: [String]

    var id: String { name }
}

enum EmojiCatalog {
    nonisolated static let groups: [EmojiGroup] = build()

    /// Flat list, used when a search is running.
    nonisolated static let all: [String] = groups.flatMap(\.emoji)

    // MARK: Search

    nonisolated private static let nameCache = NameCache()

    nonisolated static func matches(_ query: String) -> [String] {
        let needle = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !needle.isEmpty else { return [] }
        return all.filter { nameCache.name(for: $0).contains(needle) }
    }

    /// Unicode names are only looked up for what the user actually searches,
    /// and only once each.
    nonisolated private final class NameCache: @unchecked Sendable {
        private var storage: [String: String] = [:]
        private let lock = NSLock()

        func name(for emoji: String) -> String {
            lock.lock()
            defer { lock.unlock() }
            if let hit = storage[emoji] { return hit }
            let raw = emoji
                .applyingTransform(StringTransform("Any-Name"), reverse: false) ?? emoji
            // "\N{GRINNING FACE}\N{VARIATION SELECTOR-16}" -> "grinning face"
            let cleaned = raw
                .replacingOccurrences(of: "\\N{", with: " ")
                .replacingOccurrences(of: "}", with: " ")
                .replacingOccurrences(of: "VARIATION SELECTOR-16", with: "")
                .replacingOccurrences(of: "ZERO WIDTH JOINER", with: "")
                .lowercased()
            storage[emoji] = cleaned
            return cleaned
        }
    }

    // MARK: Building

    nonisolated private static func build() -> [EmojiGroup] {
        let blueprint: [(String, String, [ClosedRange<UInt32>])] = [
            ("Smileys", "face.smiling", [
                0x1F600...0x1F64F, 0x1F910...0x1F93A, 0x1F970...0x1F97A,
                0x1FAE0...0x1FAE8, 0x263A...0x263A, 0x2639...0x2639
            ]),
            ("People", "hand.wave", [
                0x1F440...0x1F450, 0x1F464...0x1F487, 0x1F574...0x1F57A,
                0x1F590...0x1F596, 0x1F918...0x1F91F, 0x1F926...0x1F937,
                0x1F9B0...0x1F9B9, 0x1F9D1...0x1F9DF, 0x1FAF0...0x1FAF8,
                0x270A...0x270D
            ]),
            ("Animals", "pawprint", [
                0x1F400...0x1F43F, 0x1F980...0x1F9AE, 0x1F54A...0x1F54A,
                0x1F577...0x1F578, 0x1FAB0...0x1FABF
            ]),
            ("Nature", "leaf", [
                0x1F300...0x1F321, 0x1F324...0x1F32C, 0x1F330...0x1F343,
                0x2600...0x2604, 0x26C4...0x26C8, 0x2744...0x2746
            ]),
            ("Food", "fork.knife", [
                0x1F344...0x1F37F, 0x1F950...0x1F96F, 0x1F9C0...0x1F9CB,
                0x1FAD0...0x1FADF, 0x2615...0x2615
            ]),
            ("Activity", "figure.run", [
                0x1F380...0x1F3C4, 0x1F3C6...0x1F3CA, 0x1F93C...0x1F94F,
                0x26BD...0x26BE, 0x26F3...0x26F9, 0x1F396...0x1F397
            ]),
            ("Travel", "airplane", [
                0x1F680...0x1F6C5, 0x1F3D4...0x1F3F0, 0x1F5FA...0x1F5FF,
                0x1F68A...0x1F6A4, 0x26F0...0x26F2, 0x26F4...0x26F5
            ]),
            ("Objects", "lightbulb", [
                0x1F4A1...0x1F4FF, 0x1F50A...0x1F53D, 0x1F6AA...0x1F6BF,
                0x1F6E0...0x1F6FC, 0x1F9F0...0x1F9FF, 0x1FA70...0x1FA7C,
                0x1FA80...0x1FA8F, 0x231A...0x231B, 0x260E...0x260E
            ]),
            ("Symbols", "heart", [
                0x1F493...0x1F49F, 0x1F4AC...0x1F4AF, 0x2049...0x2049,
                0x2611...0x2611, 0x2705...0x2705, 0x274C...0x274E,
                0x2753...0x2757, 0x2764...0x2764, 0x1F51F...0x1F525,
                0x2B50...0x2B50, 0x1F536...0x1F53D
            ])
        ]

        var groups = blueprint.map { name, icon, ranges in
            let emoji = ranges
                .flatMap { $0 }
                .compactMap { scalarValue -> String? in
                    guard let scalar = Unicode.Scalar(scalarValue) else { return nil }
                    let candidate = String(scalar)
                    return isRenderable(candidate) ? candidate : nil
                }
            return EmojiGroup(name: name, icon: icon, emoji: dedupe(emoji))
        }

        groups.append(EmojiGroup(name: "Flags", icon: "flag", emoji: flags))
        return groups.filter { !$0.emoji.isEmpty }
    }

    nonisolated private static func dedupe(_ list: [String]) -> [String] {
        var seen = Set<String>()
        return list.filter { seen.insert($0).inserted }
    }

    /// Regional indicator pairs. Only real country codes, so the grid is not
    /// 676 mostly-blank cells.
    nonisolated private static let flags: [String] = {
        let codes = [
            "US", "CA", "MX", "BR", "AR", "CL", "CO", "PE", "GB", "IE", "FR",
            "DE", "IT", "ES", "PT", "NL", "BE", "CH", "AT", "SE", "NO", "DK",
            "FI", "IS", "PL", "CZ", "GR", "TR", "UA", "RU", "EG", "MA", "NG",
            "GH", "KE", "ET", "ZA", "SN", "CI", "TZ", "IL", "SA", "AE", "QA",
            "IN", "PK", "BD", "CN", "JP", "KR", "TH", "VN", "PH", "ID", "MY",
            "SG", "AU", "NZ", "JM", "HT", "TT", "BB", "BS", "DO", "PR", "CU"
        ]
        return codes.compactMap { code in
            let scalars = code.unicodeScalars.compactMap {
                Unicode.Scalar(0x1F1E6 + ($0.value - 65))
            }
            guard scalars.count == 2 else { return nil }
            return String(String.UnicodeScalarView(scalars))
        }
    }()

    /// Ask the colour emoji font directly. Anything it has no glyph for would
    /// draw as an empty box, so it is left out.
    nonisolated private static func isRenderable(_ emoji: String) -> Bool {
        let font = CTFontCreateWithName("AppleColorEmoji" as CFString, 20, nil)
        var utf16 = Array(emoji.utf16)
        var glyphs = [CGGlyph](repeating: 0, count: utf16.count)
        return CTFontGetGlyphsForCharacters(font, &utf16, &glyphs, utf16.count)
    }
}
