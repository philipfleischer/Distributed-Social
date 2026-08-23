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

    @Environment(PlayerViewModel.self) private var playerVM
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.displayScale) private var displayScale

    private var theme: AppTheme { themeStore.theme }
    private var isActive: Bool { playerVM.currentPlaylistID == playlist.id }

    private var seed: Int {
        let u = playlist.id.uuid
        return Int(u.0) ^ Int(u.1 &* 17) ^ Int(u.2 &* 31)
    }

    @State private var decodedCover: (key: String, image: UIImage?)? = nil
    private static let coverPointSize: CGFloat = 200

    /// Single pass: returns both the cache key and the raw data for the cover
    /// (custom image → first song artwork → nil). Using a lazy loop avoids the
    /// two separate O(n) traversals that `coverKey` and `coverData` used to do.
    private var coverSource: (key: String, data: Data?) {
        if let data = playlist.imageData {
            return ("pl-\(playlist.id.uuidString)-custom-\(data.count)", data)
        }
        for item in playlist.orderedItems ?? [] {
            if let mediaItem = item.mediaItem, let data = mediaItem.artworkData {
                return ("item-\(mediaItem.id.uuidString)", data)
            }
        }
        return ("pl-\(playlist.id.uuidString)-generated", nil)
    }

    private func resolvedCoverImage(forKey key: String) -> UIImage? {
        if let hit = ArtworkThumbnailCache.image(forKey: key, pointSize: Self.coverPointSize) { return hit }
        if let dc = decodedCover, dc.key == key { return dc.image }
        return nil
    }

    var body: some View {
        let cs = coverSource
        let resolvedImage = resolvedCoverImage(forKey: cs.key)
        VStack(alignment: .leading, spacing: 8) {
            coverView(image: resolvedImage)
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
            let count = playlist.orderedItems?.count ?? 0
            Text("\(count) item\(count == 1 ? "" : "s")")
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
        }
        .task(id: cs.key) {
            guard resolvedCoverImage(forKey: cs.key) == nil, let data = cs.data else { return }
            let image = await ArtworkThumbnailCache.loadThumbnail(
                forKey: cs.key, data: data,
                pointSize: Self.coverPointSize, scale: displayScale)
            decodedCover = (cs.key, image)
        }
    }

    @ViewBuilder
    private func coverView(image: UIImage?) -> some View {
        if let uiImage = image {
            Color.clear
                .overlay(
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                )
        } else {
            generatedCover
        }
    }

    private var generatedCover: some View {
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
