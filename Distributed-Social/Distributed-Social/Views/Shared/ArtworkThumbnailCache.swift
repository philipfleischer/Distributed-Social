//
//  ArtworkThumbnailCache.swift
//  Distributed-Social
//
//  Process-wide cache of decoded, display-sized artwork. UIImage(data:)
//  re-decodes the full-resolution blob on every call, so decoding inside
//  a view body burned CPU (battery/heat) on every list re-render. Views
//  ask this cache instead: each artwork is downsampled to its display
//  size once, off the main thread, then reused.
//

import UIKit
import ImageIO

enum ArtworkThumbnailCache {
    private static let images = NSCache<NSString, UIImage>()

    /// Synchronous lookup for view bodies — returns instantly on re-render
    /// or scroll-back without touching the model's data blob.
    static func image(forKey key: String, pointSize: CGFloat) -> UIImage? {
        images.object(forKey: cacheKey(key, pointSize))
    }

    /// Decodes `data` downsampled to `pointSize` (× `scale` for pixels),
    /// caches the result under `key`, and returns it. The decode runs off
    /// the main thread.
    static func loadThumbnail(forKey key: String, data: Data,
                              pointSize: CGFloat, scale: CGFloat) async -> UIImage? {
        if let hit = image(forKey: key, pointSize: pointSize) { return hit }
        let maxPixel = pointSize * max(scale, 1)
        let decoded = await Task.detached(priority: .userInitiated) {
            downsample(data: data, maxPixel: maxPixel)
        }.value
        if let decoded {
            images.setObject(decoded, forKey: cacheKey(key, pointSize))
        }
        return decoded
    }

    /// Re-encodes a user-picked cover photo at a sane size before it is
    /// persisted — camera images are often 5–10 MB and covers render at
    /// ~200 pt, so storing them full-size wastes disk and decode time.
    /// Returns nil when the data can't be decoded.
    static func downscaledCoverData(from data: Data, maxPixel: CGFloat = 1000) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            downsample(data: data, maxPixel: maxPixel)?.jpegData(compressionQuality: 0.85)
        }.value
    }

    private static func cacheKey(_ key: String, _ pointSize: CGFloat) -> NSString {
        "\(key)#\(Int(pointSize))" as NSString
    }

    /// ImageIO downsampling decodes straight to thumbnail size without ever
    /// materializing the full-resolution bitmap in memory.
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
