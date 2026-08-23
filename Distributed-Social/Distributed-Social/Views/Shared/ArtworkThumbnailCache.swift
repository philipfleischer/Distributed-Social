//
//  ArtworkThumbnailCache.swift
//  Distributed-Social
//
//  Two-level artwork cache: in-memory NSCache for the current session and a
//  disk cache in Caches/Thumbnails/ that survives app restarts.
//
//  Cold-start flow per image:
//    memory miss → disk hit  → UIImage(data:) on small JPEG (~5 ms, off-thread)
//    memory miss → disk miss → ImageIO downsample + write to disk (~100 ms, off-thread)
//
//  The system may purge Caches/ under storage pressure; that just forces a
//  one-time re-decode on the next launch, with the result written to disk again.
//

import UIKit
import ImageIO

enum ArtworkThumbnailCache {
    private static let images: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 48 * 1024 * 1024
        return cache
    }()

    /// Lazily-created disk cache directory. Swift's static let guarantees
    /// thread-safe one-time initialisation.
    private static let diskCacheDir: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = caches.appendingPathComponent("Thumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// Synchronous in-memory lookup for view bodies.
    static func image(forKey key: String, pointSize: CGFloat) -> UIImage? {
        images.object(forKey: memKey(key, pointSize))
    }

    /// Returns a thumbnail for `key`, going through memory → disk → decode.
    /// The decode and disk I/O run off the main thread.
    static func loadThumbnail(forKey key: String, data: Data,
                              pointSize: CGFloat, scale: CGFloat) async -> UIImage? {
        let mk = memKey(key, pointSize)

        // 1. Memory cache (synchronous, main thread is fine here)
        if let hit = images.object(forKey: mk) { return hit }

        let maxPixel = pointSize * max(scale, 1)
        let decoded = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            // 2. Disk cache — reading a small pre-scaled JPEG is ~5 ms
            if let cached = readFromDisk(memKey: mk) { return cached }

            // 3. Full ImageIO decode from source artwork data
            guard let image = downsample(data: data, maxPixel: maxPixel) else { return nil }

            // 4. Persist so subsequent launches skip step 3
            writeToDisk(image: image, memKey: mk)

            return image
        }.value

        if let decoded {
            let cost = Int(decoded.size.width * decoded.size.height * decoded.scale * decoded.scale) * 4
            images.setObject(decoded, forKey: mk, cost: cost)
        }
        return decoded
    }

    /// Re-encodes a user-picked cover photo at a sane size before persistence.
    static func downscaledCoverData(from data: Data, maxPixel: CGFloat = 1000) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            downsample(data: data, maxPixel: maxPixel)?.jpegData(compressionQuality: 0.85)
        }.value
    }

    // MARK: - Private helpers

    private static func memKey(_ key: String, _ pointSize: CGFloat) -> NSString {
        "\(key)#\(Int(pointSize))" as NSString
    }

    /// Disk filename: replace '#' (size separator) with '_', append .jpg.
    /// The result is a valid filename on every Apple filesystem.
    private static func diskURL(for memKey: NSString) -> URL {
        let filename = (memKey as String).replacingOccurrences(of: "#", with: "_") + ".jpg"
        return diskCacheDir.appendingPathComponent(filename)
    }

    nonisolated private static func readFromDisk(memKey: NSString) -> UIImage? {
        guard let data = try? Data(contentsOf: diskURL(for: memKey)) else { return nil }
        return UIImage(data: data)
    }

    nonisolated private static func writeToDisk(image: UIImage, memKey: NSString) {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        // .atomic prevents a torn file if the process is killed mid-write.
        try? data.write(to: diskURL(for: memKey), options: .atomic)
    }

    /// ImageIO downsampling — decodes straight to thumbnail size without
    /// materialising the full-resolution bitmap in memory.
    nonisolated private static func downsample(data: Data, maxPixel: CGFloat) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
