//
//  FullPlayerView.swift
//  Distributed-Social
//
//  Presented as an overlay above the TabView (not a sheet), so the tab bar
//  stays visible and usable while the player is open.
//

import SwiftUI

struct FullPlayerView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @State private var itemForPlaylist: MediaItem?

    var body: some View {
        VStack(spacing: 24) {
            header

            if playerVM.currentItem?.mediaType == .video {
                VideoPlayerView(player: playerVM.avPlayer)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
            } else if let item = playerVM.currentItem {
                // Unique per-item artwork, matching the library rows.
                MediaArtworkView(item: item, size: 240)
                    .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
            }

            // Title
            Text(playerVM.currentItem?.displayName ?? "")
                .font(.title)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            PlayerControlsView()

            Spacer(minLength: 0)
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient.summerSky
                .background(Color.softWhite)
                .ignoresSafeArea(edges: .top)
        )
        .sheet(item: $itemForPlaylist) { item in
            AddToPlaylistSheet(item: item)
        }
    }

    /// Dismiss chevron on the left, "⋮" actions menu on the right.
    private var header: some View {
        HStack {
            Button {
                playerVM.isFullPlayerPresented = false
            } label: {
                Image(systemName: "chevron.down")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Menu {
                if let item = playerVM.currentItem {
                    Button { itemForPlaylist = item } label: {
                        Label("Add to Playlist", systemImage: "text.badge.plus")
                    }
                    Button { item.isFavorite.toggle() } label: {
                        Label(
                            item.isFavorite ? "Remove from Favorites" : "Favorite",
                            systemImage: item.isFavorite ? "heart.slash" : "heart"
                        )
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3.weight(.semibold))
                    .rotationEffect(.degrees(90))
                    .frame(width: 44, height: 44)
            }
        }
        .foregroundStyle(Color.deepSky)
        .padding(.horizontal, 12)
    }
}
