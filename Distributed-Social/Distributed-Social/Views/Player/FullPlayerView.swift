//
//  FullPlayerView.swift
//  Distributed-Social
//
//  Presented as an overlay above the TabView (not a sheet), so the tab bar
//  stays visible and usable while the player is open. Dismiss via the
//  chevron or by swiping down.
//

import SwiftUI

struct FullPlayerView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var themeStore: ThemeStore
    @State private var itemForPlaylist: MediaItem?
    @State private var dragOffset: CGFloat = 0

    private var theme: AppTheme { themeStore.theme }

    var body: some View {
        VStack(spacing: 16) {
            header

            if playerVM.currentItem?.mediaType == .video {
                VideoPlayerView(player: playerVM.avPlayer)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
            } else if let item = playerVM.currentItem {
                // Large cover art filling the width, pushing controls down.
                MediaArtworkView(item: item, size: 330)
                    .shadow(color: .black.opacity(0.5), radius: 14, y: 7)
            }

            // Title + artist (from embedded tags, when available)
            VStack(spacing: 4) {
                Text(playerVM.currentItem?.displayName ?? "")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                if let artist = playerVM.currentItem?.artist {
                    Text(artist)
                        .font(.title3)
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .padding(.horizontal)

            PlayerControlsView()

            Spacer(minLength: 0)
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            theme.background
                .background(theme.backgroundColors.first ?? .black)
                .ignoresSafeArea(edges: .top)
        )
        .offset(y: max(0, dragOffset))
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.height
                }
                .onEnded { value in
                    if value.translation.height > 90 {
                        playerVM.isFullPlayerPresented = false
                    }
                    dragOffset = 0
                }
        )
        .animation(.spring(duration: 0.3), value: dragOffset)
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
        .foregroundStyle(theme.textPrimary)
        .padding(.horizontal, 12)
    }
}
