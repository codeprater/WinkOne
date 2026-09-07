import Foundation
import UIKit

enum WinkSymbol {
    static let send = "paperplane.fill"
    static let inbox = "tray.badge.fill"
    static let nearby = "point.3.connected.trianglepath.dotted"
}

struct SFSymbolRecord: Identifiable, Hashable, Decodable {
    let n: String
    let c: String
    let k: String
    var id: String { n }
    var name: String { n }
    var category: String { c }
}

struct SFSymbolCategory: Identifiable, Hashable, Decodable {
    let key: String
    let label: String
    var id: String { key }
}

enum SFSymbolCatalog {
    private struct File: Decodable {
        let categories: [SFSymbolCategory]
        let symbols: [SFSymbolRecord]
    }

    static let categories: [SFSymbolCategory] = file.categories
    static let symbols: [SFSymbolRecord] = file.symbols

    private static let file: File = {
        guard let url = Bundle.main.url(forResource: "SFSymbolCatalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(File.self, from: data)
        else {
            return File(categories: [], symbols: [])
        }
        return decoded
    }()

    static func matches(_ query: String, category: String) -> [SFSymbolRecord] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let base: [SFSymbolRecord]
        if category.isEmpty {
            base = symbols
        } else {
            base = symbols.filter { $0.category == category }
        }
        if needle.isEmpty {
            if category.isEmpty {
                var seen = Set<String>()
                var ordered: [SFSymbolRecord] = []
                for item in featured + symbols.prefix(80) {
                    if seen.insert(item.name).inserted { ordered.append(item) }
                }
                return ordered
            }
            return Array(base.prefix(200))
        }
        return base.filter { record in
            record.name.localizedCaseInsensitiveContains(needle)
                || record.k.localizedCaseInsensitiveContains(needle)
        }.prefix(400).map { $0 }
    }

    static let featured: [SFSymbolRecord] = {
        let names = [WinkSymbol.send, WinkSymbol.inbox, WinkSymbol.nearby, "heart.fill", "hand.wave.fill", "bolt.fill", "eye.fill", "wineglass.fill"]
        return names.compactMap { name in symbols.first { $0.name == name } }
    }()

    static func isAvailable(_ name: String) -> Bool {
        UIImage(systemName: name) != nil
    }
}
