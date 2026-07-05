//
//  FavoritesView.swift
//  Distributed-Social
//
//  The full list of hearted songs, presented like an ordinary playlist.
//

import SwiftUI
import SwiftData

struct FavoritesView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var themeStore: ThemeStore
    @Query(sort: \MediaItem.dateImported, order: .reverse) private var allItems: [MediaItem]

    private var theme: AppTheme { themeStore.theme }

    private var favorites: [MediaItem] {
        allItems.filter { $0.isFavorite }
    }

    var body: some View {
        Group {
            if favorites.isEmpty {
                ContentUnavailableView(
                    "No Favorites",
                    systemImage: "heart",
                    description: Text("Tap the heart in the player to favorite a song.")
                )
            } else {
                List(favorites) { item in
                    let isCurrent = playerVM.currentItem?.id == item.id
                    HStack(spacing: 12) {
                        MediaArtworkView(item: item, size: 56)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.displayName)
                                .font(.headline)
                                .foregroundStyle(isCurrent ? theme.textHighlight : theme.textPrimary)
                                .lineLimit(1)
                            HStack(spacing: 8) {
                                if isCurrent {
                                    Image(systemName: "waveform")
                                        .font(.subheadline)
                                        .foregroundStyle(theme.textPrimary)
                                        .symbolEffect(.variableColor.iterative, isActive: playerVM.isPlaying)
                                }
                                if let artist = item.artist {
                                    Text(artist)
                                        .font(.subheadline)
                                        .foregroundStyle(theme.textSecondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        Spacer()
                        Text(item.duration.formattedTime)
                            .font(.subheadline)
                            .foregroundStyle(theme.textSecondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        playerVM.currentPlaylistID = nil
                        playerVM.play(item: item, in: favorites)
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            playerVM.addToQueue(item)
                        } label: {
                            Label("Queue", systemImage: "text.append")
                        }
                        .tint(.green)
                    }
                    .swipeActions(edge: .trailing) {
                        Button {
                            item.isFavorite = false
                        } label: {
                            Label("Unfavorite", systemImage: "heart.slash")
                        }
                        .tint(.red)
                    }
                    .listRowBackground(Color.clear)
                }
                .scrollContentBackground(.hidden)
                .contentMargins(.bottom, 120, for: .scrollContent) // clear the mini player
            }
        }
        .summerBackground()
        .navigationTitle("Favorites")
    }
}
