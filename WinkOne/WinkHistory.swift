import CoreGraphics
import Foundation
import ImageIO
import PencilKit
import UIKit

// MARK: - Where history lives
//
// It used to live in UserDefaults, which was the bug. UserDefaults is loaded
// into memory in its entirety and rewritten whole on every change, and a
// WinkPayload can carry a 1.5 MB photo. A hundred received cards plus a
// hundred sent ones meant re-serializing a few hundred megabytes on the main
// thread every time a single wink arrived — which is exactly the CPU, energy
// and memory spike. History belongs in a file.

// The project builds with SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor, so every
// declaration here is MainActor unless it says otherwise. Nothing in this type
// touches UI, and `write` is called from a background task, so the whole thing
// is nonisolated.
enum WinkHistoryFile {
    /// Application Support, not Documents: this is app state, not user data,
    /// and it should not show up in the Files app.
    nonisolated private static var directory: URL? {
        guard let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return nil }
        let folder = base.appendingPathComponent("WinkOne", isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(
                at: folder,
                withIntermediateDirectories: true
            )
        }
        return folder
    }

    nonisolated static func url(_ name: String) -> URL? {
        directory?.appendingPathComponent(name)
    }

    nonisolated static func read(_ name: String) -> Data? {
        guard let url = url(name) else { return nil }
        return try? Data(contentsOf: url)
    }

    /// The write itself goes off the main thread. Callers encode first, so all
    /// that crosses the boundary is a `Data`.
    nonisolated static func write(_ data: Data, to name: String) {
        guard let url = url(name) else { return }
        Task.detached(priority: .utility) {
            try? data.write(to: url, options: .atomic)
        }
    }
}

// MARK: - Shrinking what gets kept

enum PhotoThumb {
    /// A history card is shown at roughly a third of the screen. There is no
    /// reason to keep the send-sized image around for it.
    nonisolated static let longEdge: CGFloat = 480
    nonisolated static let quality: CGFloat = 0.6

    nonisolated static func shrink(_ data: Data) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > longEdge else {
            return image.jpegData(compressionQuality: quality) ?? data
        }
        let scale = longEdge / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let shrunk = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return shrunk.jpegData(compressionQuality: quality) ?? data
    }
}

extension WinkPayload {
    /// The version of a card that is safe to keep forever. The card on screen
    /// still uses the full-size data; only the archived copy is shrunk.
    var historySafe: WinkPayload {
        var copy = self
        if let photo = photoData, photo.count > 120_000 {
            copy.photoData = PhotoThumb.shrink(photo)
        }
        return copy
    }
}

// MARK: - Decoding once instead of every frame

/// `UIImage(data:)` inline in a view body re-decodes the whole JPEG on every
/// render pass. In the library that is one full decode per tile per pass.
/// This decodes once, at the size actually needed, and keeps the result.
@MainActor
final class DecodedImageCache {
    static let shared = DecodedImageCache()

    private let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 60
        cache.totalCostLimit = 48 * 1024 * 1024
        return cache
    }()

    private init() {}

    /// Cheap and good enough: length plus a handful of sampled bytes. Hashing
    /// the whole `Data` on every render would cost more than the decode we are
    /// trying to avoid.
    private static func key(for data: Data, maxPixel: CGFloat) -> NSString {
        var fingerprint = UInt64(data.count)
        let stride = max(1, data.count / 16)
        var index = data.startIndex
        while index < data.endIndex {
            fingerprint = fingerprint &* 31 &+ UInt64(data[index])
            index = data.index(index, offsetBy: stride, limitedBy: data.endIndex) ?? data.endIndex
        }
        return "\(data.count)-\(fingerprint)-\(Int(maxPixel))" as NSString
    }

    func image(for data: Data, maxPixel: CGFloat) -> UIImage? {
        let key = Self.key(for: data, maxPixel: maxPixel)
        if let hit = cache.object(forKey: key) { return hit }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else {
            // Fall back to a plain decode rather than showing nothing.
            let image = UIImage(data: data)
            if let image { cache.setObject(image, forKey: key, cost: data.count) }
            return image
        }

        let image = UIImage(cgImage: cgImage)
        cache.setObject(image, forKey: key, cost: cgImage.bytesPerRow * cgImage.height)
        return image
    }

    /// Same problem, different source: rendering a PKDrawing re-parses the
    /// stroke data and rasterizes at 3x on every render pass.
    func drawing(for data: Data) -> UIImage? {
        let key = Self.key(for: data, maxPixel: -1)
        if let hit = cache.object(forKey: key) { return hit }
        guard let drawing = try? PKDrawing(data: data) else { return nil }

        let bounds = drawing.bounds.insetBy(dx: -24, dy: -24)
        let renderBounds = (bounds.isNull || bounds.isEmpty)
            ? CGRect(x: 0, y: 0, width: 400, height: 280)
            : bounds
        let image = drawing.image(from: renderBounds, scale: 2)
        cache.setObject(
            image,
            forKey: key,
            cost: Int(image.size.width * image.size.height * 4)
        )
        return image
    }
}
