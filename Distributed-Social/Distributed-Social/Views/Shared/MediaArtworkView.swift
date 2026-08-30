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

    private var generatedArtwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.21)
                .fill(Color.black)
            Image(systemName: item.mediaType.systemImage)
                .font(.system(size: size * 0.40, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}
