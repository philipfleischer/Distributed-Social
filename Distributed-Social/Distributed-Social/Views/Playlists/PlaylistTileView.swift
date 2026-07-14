//
//  PlaylistTileView.swift
//  Distributed-Social
//
//  A square playlist cover. Priority: the user's chosen image, then the
//  first song's embedded album art, and only as a last resort the unique
//  generated gradient + motif.
//

import SwiftUI

struct PlaylistTileView: View {
    let playlist: Playlist
    var size: CGFloat? = nil        // nil → flexible (grid) sizing
    var isActive: Bool = false      // true when this playlist is playing

    @EnvironmentObject var themeStore: ThemeStore
    private var theme: AppTheme { themeStore.theme }

    private var seed: Int {
        var value = 0
        for scalar in playlist.id.uuidString.unicodeScalars {
            value = (value &* 17 &+ Int(scalar.value)) & 0xFFFF
        }
        return value
    }

    @Environment(\.displayScale) private var displayScale
    /// Freshly decoded cover, tagged with the cache key it belongs to so a
    /// reused tile never shows another playlist's cover.
    @State private var decodedCover: (key: String, image: UIImage?)? = nil

    /// Covers render at grid-tile size at most; decode once at this size.
    private static let coverPointSize: CGFloat = 200

    /// Custom cover if chosen, otherwise the first available song artwork.
    private var coverData: Data? {
        if let data = playlist.imageData { return data }
        return playlist.sortedItems.compactMap { $0.mediaItem?.artworkData }.first
    }

    /// Identity of whatever the cover shows. Changing the custom image or
    /// the underlying songs produces a new key, so stale cache entries are
    /// simply never looked up again.
    private var coverKey: String {
        if let data = playlist.imageData {
            return "pl-\(playlist.id.uuidString)-custom-\(data.count)"
        }
        if let item = playlist.sortedItems.compactMap(\.mediaItem).first(where: { $0.artworkData != nil }) {
            return "item-\(item.id.uuidString)"
        }
        return "pl-\(playlist.id.uuidString)-generated"
    }

    /// Cached decode if available; decoding never happens in the body.
    private var resolvedCover: UIImage? {
        if let hit = ArtworkThumbnailCache.image(forKey: coverKey, pointSize: Self.coverPointSize) {
            return hit
        }
        if let decodedCover, decodedCover.key == coverKey { return decodedCover.image }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            cover
                .aspectRatio(1, contentMode: .fit)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(theme.textPrimary, lineWidth: isActive ? 3 : 0)
                )
                .overlay(alignment: .topTrailing) {
                    if isActive {
                        Image(systemName: "waveform")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(theme.backgroundColors.first ?? .black)
                            .padding(6)
                            .background(theme.textPrimary)
                            .clipShape(Circle())
                            .padding(8)
                    }
                }
                .shadow(color: .black.opacity(0.4), radius: 6, y: 3)

            MarqueeText(text: playlist.name, font: .headline, color: theme.textPrimary)
            // Counting doesn't need the sorted order — skip the sort.
            let count = playlist.orderedItems?.count ?? 0
            Text("\(count) item\(count == 1 ? "" : "s")")
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
        }
        .task(id: coverKey) {
            guard resolvedCover == nil, let data = coverData else { return }
            let image = await ArtworkThumbnailCache.loadThumbnail(
                forKey: coverKey, data: data,
                pointSize: Self.coverPointSize, scale: displayScale)
            decodedCover = (coverKey, image)
        }
    }

    @ViewBuilder
    private var cover: some View {
        if let uiImage = resolvedCover {
            Color.clear
                .overlay(
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                )
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.artworkHue(for: playlist.id),
                        Color.artworkHue(for: playlist.id, offset: 0.16)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                decorativeShape
                    .foregroundStyle(.white.opacity(0.30))

                Image(systemName: playlist.mediaType.systemImage)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
            }
        }
    }

    @ViewBuilder
    private var decorativeShape: some View {
        GeometryReader { geo in
            let s = geo.size.width
            switch seed % 4 {
            case 0:
                Circle()
                    .frame(width: s * 0.85, height: s * 0.85)
                    .offset(x: s * 0.35, y: -s * 0.25)
            case 1:
                RoundedRectangle(cornerRadius: s * 0.1)
                    .frame(width: s * 0.7, height: s * 0.7)
                    .rotationEffect(.degrees(35))
                    .offset(x: -s * 0.2, y: s * 0.55)
            case 2:
                Capsule()
                    .frame(width: s * 1.2, height: s * 0.35)
                    .rotationEffect(.degrees(-40))
                    .offset(x: s * 0.05, y: s * 0.3)
            default:
                Circle()
                    .strokeBorder(lineWidth: s * 0.09)
                    .frame(width: s * 0.9, height: s * 0.9)
                    .offset(x: -s * 0.2, y: -s * 0.2)
            }
        }
    }
}
