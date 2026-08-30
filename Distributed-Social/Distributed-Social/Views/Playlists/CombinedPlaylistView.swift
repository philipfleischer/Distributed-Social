//
//  CombinedPlaylistView.swift
//  Distributed-Social
//
//  Temporary in-session playlist assembled from user-selected playlists.
//  Not persisted — disappears when the app restarts.
//

import SwiftUI

struct CombinedPlaylistView: View {
    let items: [MediaItem]

    @Environment(PlayerViewModel.self) private var playerVM
    @Environment(ThemeStore.self) private var themeStore
    private var theme: AppTheme { themeStore.theme }

    @State private var searchText = ""

    private var visibleItems: [MediaItem] {
        guard !searchText.isEmpty else { return items }
        return items.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
                || ($0.artist?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private var playableItems: [MediaItem] { visibleItems.filter { !$0.isFileMissing } }

    private var searchBarRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(theme.textSecondary)
            TextField("Search", text: $searchText)
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
            if items.isEmpty {
                ContentUnavailableView(
                    "No Songs",
                    systemImage: "list.bullet",
                    description: Text("The selected playlists have no songs.")
                )
            } else {
                List {
                    searchBarRow
                    ForEach(visibleItems) { item in
                        let isCurrent = playerVM.currentItem?.id == item.id
                        let isMissing = item.isFileMissing
                        HStack(spacing: 10) {
                            MediaArtworkView(item: item, size: 44)
                                .saturation(isMissing ? 0 : 1)
                                .opacity(isMissing ? 0.4 : 1)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.displayName)
                                    .font(.body.weight(isCurrent ? .semibold : .regular))
                                    .foregroundStyle(isMissing ? .gray : (isCurrent ? theme.textHighlight : theme.textPrimary))
                                    .lineLimit(1)
                                if let artist = item.artist {
                                    Text(artist)
                                        .font(.caption)
                                        .foregroundStyle(theme.textSecondary)
                                        .lineLimit(1)
                                }
                            }
                            if isCurrent && !isMissing {
                                Image(systemName: "waveform")
                                    .foregroundStyle(theme.textPrimary)
                                    .symbolEffect(.variableColor.iterative, isActive: playerVM.isPlaying)
                            }
                            Spacer()
                            Text(item.duration.formattedTime)
                                .font(.caption)
                                .foregroundStyle(isMissing ? Color.gray : theme.textSecondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard !isMissing else { return }
                            playerVM.currentPlaylistID = nil
                            playerVM.play(item: item, in: playableItems)
                        }
                        .swipeToQueue(enabled: !isMissing) {
                            playerVM.addToQueue(item)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .scrollContentBackground(.hidden)
                .contentMargins(.bottom, 120, for: .scrollContent)
            }
        }
        .summerBackground()
        .navigationTitle("Combined Playlist")
        .disableSwipeBack()
        .toolbar {
            if !playableItems.isEmpty {
                Button {
                    let shuffled = playableItems.shuffled()
                    playerVM.currentPlaylistID = nil
                    playerVM.play(item: shuffled[0], in: shuffled)
                } label: {
                    Label("Shuffle", systemImage: "shuffle")
                }
            }
        }
    }
}
