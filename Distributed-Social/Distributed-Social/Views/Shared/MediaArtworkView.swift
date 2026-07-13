//
//  MediaArtworkView.swift
//  Distributed-Social
//
//  A unique, deterministic artwork tile per media item: a gradient of hues
//  derived from the item's UUID plus a varying decorative shape, so files
//  are easy to tell apart at a glance.
//

import SwiftUI

struct MediaArtworkView: View {
    let item: MediaItem
    var size: CGFloat = 56

    @Environment(\.displayScale) private var displayScale
    /// Freshly decoded thumbnail, tagged with the item it belongs to so a
    /// reused row never shows the previous item's artwork.
    @State private var decoded: (itemID: UUID, image: UIImage?)? = nil

    private var cacheKey: String { "item-\(item.id.uuidString)" }

    /// Cached decode if available; decoding never happens in the body.
    private var resolvedImage: UIImage? {
        if let hit = ArtworkThumbnailCache.image(forKey: cacheKey, pointSize: size) {
            return hit
        }
        if let decoded, decoded.itemID == item.id { return decoded.image }
        return nil
    }

    /// True when the decode ran for this item but produced no image
    /// (corrupt data) — fall back to the generated artwork.
    private var decodeFailed: Bool {
        decoded?.itemID == item.id && decoded?.image == nil
    }

    /// Stable per-item value used to vary the decorative shape.
    private var seed: Int {
        var value = 0
        for scalar in item.id.uuidString.unicodeScalars {
            value = (value &* 17 &+ Int(scalar.value)) & 0xFFFF
        }
        return value
    }

    var body: some View {
        Group {
            if let uiImage = resolvedImage {
                // Embedded cover art from the file's tags.
                Color.clear
                    .overlay(
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    )
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.21))
            } else if item.artworkData == nil || decodeFailed {
                generatedArtwork
            } else {
                // Artwork exists but its decode hasn't finished yet.
                RoundedRectangle(cornerRadius: size * 0.21)
                    .fill(.gray.opacity(0.15))
            }
        }
        .frame(width: size, height: size)
        .task(id: item.id) {
            guard resolvedImage == nil, let data = item.artworkData else { return }
            let image = await ArtworkThumbnailCache.loadThumbnail(
                forKey: cacheKey, data: data, pointSize: size, scale: displayScale)
            decoded = (item.id, image)
        }
    }

    /// Fallback: unique gradient + motif derived from the item's UUID.
    private var generatedArtwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.21)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.artworkHue(for: item.id),
                            Color.artworkHue(for: item.id, offset: 0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            decorativeShape
                .foregroundStyle(.white.opacity(0.30))

            Image(systemName: item.mediaType.systemImage)
                .font(.system(size: size * 0.40, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
        }
    }

    /// One of a few background motifs, chosen deterministically per item.
    @ViewBuilder
    private var decorativeShape: some View {
        switch seed % 4 {
        case 0:
            Circle()
                .frame(width: size * 0.8, height: size * 0.8)
                .offset(x: size * 0.28, y: -size * 0.28)
        case 1:
            RoundedRectangle(cornerRadius: size * 0.1)
                .frame(width: size * 0.7, height: size * 0.7)
                .rotationEffect(.degrees(35))
                .offset(x: -size * 0.3, y: size * 0.3)
        case 2:
            Capsule()
                .frame(width: size * 1.1, height: size * 0.35)
                .rotationEffect(.degrees(-40))
        default:
            Circle()
                .strokeBorder(lineWidth: size * 0.09)
                .frame(width: size * 0.85, height: size * 0.85)
                .offset(x: -size * 0.25, y: -size * 0.3)
        }
    }
}
