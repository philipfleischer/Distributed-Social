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

    private var seed: Int {
        var value = 0
        for scalar in playlist.id.uuidString.unicodeScalars {
            value = (value &* 17 &+ Int(scalar.value)) & 0xFFFF
        }
        return value
    }

    /// Custom cover if chosen, otherwise the first available song artwork.
    private var coverData: Data? {
        if let data = playlist.imageData { return data }
        return playlist.sortedItems.compactMap { $0.mediaItem?.artworkData }.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            cover
                .aspectRatio(1, contentMode: .fit)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(Color.skyBlue, lineWidth: isActive ? 3 : 0)
                )
                .overlay(alignment: .topTrailing) {
                    if isActive {
                        Image(systemName: "waveform")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.black)
                            .padding(6)
                            .background(Color.skyBlue)
                            .clipShape(Circle())
                            .padding(8)
                    }
                }
                .shadow(color: .black.opacity(0.4), radius: 6, y: 3)

            MarqueeText(text: playlist.name, font: .headline, color: .skyBlue)
            Text("\(playlist.sortedItems.count) item\(playlist.sortedItems.count == 1 ? "" : "s")")
                .font(.subheadline)
                .foregroundStyle(Color.inkSecondary)
        }
    }

    @ViewBuilder
    private var cover: some View {
        if let data = coverData, let uiImage = UIImage(data: data) {
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
