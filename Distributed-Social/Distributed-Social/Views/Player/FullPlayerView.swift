//
//  FullPlayerView.swift
//  Distributed-Social
//
//  Full-screen overlay above the TabView (covers the tab bar). Dismiss via
//  the chevron or by swiping down; swipe horizontally to switch songs.
//

import SwiftUI

struct FullPlayerView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var themeStore: ThemeStore
    @State private var itemForPlaylist: MediaItem?
    @State private var showQueue = false
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
                .ignoresSafeArea()
        )
        .offset(y: max(0, dragOffset))
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Only vertical pulls move the sheet; horizontal swipes
                    // are reserved for track switching.
                    if abs(value.translation.height) > abs(value.translation.width) {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    let horizontal = value.translation.width
                    let vertical = value.translation.height
                    if abs(horizontal) > abs(vertical) {
                        // Horizontal swipe: left → next song, right → previous.
                        if horizontal < -60 {
                            playerVM.nextTrack()
                        } else if horizontal > 60 {
                            playerVM.previousTrack()
                        }
                    } else if vertical > 90 {
                        playerVM.isFullPlayerPresented = false
                    }
                    dragOffset = 0
                }
        )
        .animation(.spring(duration: 0.3), value: dragOffset)
        .sheet(item: $itemForPlaylist) { item in
            AddToPlaylistSheet(item: item)
        }
        .sheet(isPresented: $showQueue) {
            QueueSheet()
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

            Button {
                showQueue = true
            } label: {
                Image(systemName: "list.number")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
            }

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
