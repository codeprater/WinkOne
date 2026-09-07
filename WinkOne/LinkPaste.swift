import Foundation
import UIKit

enum LinkPaste {
    static func normalized(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        if let match = detector?.firstMatch(in: trimmed, options: [], range: range),
           let url = match.url {
            return url.absoluteString
        }

        let lowered = trimmed.lowercased()
        if lowered.hasPrefix("http://") || lowered.hasPrefix("https://") {
            return trimmed
        }
        if trimmed.contains("."), !trimmed.contains(" ") {
            return "https://\(trimmed)"
        }
        return nil
    }

    static func fromPasteboard() -> String? {
        guard let string = UIPasteboard.general.string else { return nil }
        return normalized(string)
    }

    static func host(from urlString: String) -> String? {
        guard let url = URL(string: urlString), let host = url.host, !host.isEmpty else { return nil }
        return host.replacingOccurrences(of: "www.", with: "")
    }
}
