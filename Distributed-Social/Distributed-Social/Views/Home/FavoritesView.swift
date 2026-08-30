//
//  FavoritesView.swift
//  Distributed-Social
//
//  The full list of hearted songs, presented like an ordinary playlist.
//

import SwiftUI
import SwiftData

struct FavoritesView: View {
    @Environment(PlayerViewModel.self) private var playerVM
    @Environment(ThemeStore.self) private var themeStore
    @Query(filter: #Predicate<MediaItem> { $0.isFavorite },
           sort: \MediaItem.dateImported, order: .reverse) private var favorites: [MediaItem]

    @State private var searchText = ""

    private var theme: AppTheme { themeStore.theme }

    private var visibleFavorites: [MediaItem] {
        guard !searchText.isEmpty else { return favorites }
        return favorites.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
                || ($0.artist?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(theme.textSecondary)
            TextField("Search favorites", text: $searchText)
                .foregroundStyle(theme.textPrimary)
                .tint(theme.textPrimary)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(theme.chipFill, in: RoundedRectangle(cornerRadius: 10))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
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
                List {
                    searchBar
                    ForEach(visibleFavorites) { item in
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
                            playerVM.play(item: item, in: visibleFavorites)
                        }
                        .swipeToQueue {
                            playerVM.addToQueue(item)
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
                }
                .scrollContentBackground(.hidden)
                .contentMargins(.bottom, 120, for: .scrollContent)
            }
        }
        .summerBackground()
        .navigationTitle("Favorites")
        .disableSwipeBack()
        .toolbar {
            if !favorites.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let playable = visibleFavorites.filter { !$0.isFileMissing }.shuffled()
                        if let first = playable.first {
                            playerVM.currentPlaylistID = nil
                            playerVM.play(item: first, in: playable)
                        }
                    } label: {
                        Label("Shuffle", systemImage: "shuffle")
                    }
                }
            }
        }
    }
}
