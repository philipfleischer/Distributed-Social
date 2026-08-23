//
//  PlaylistDetailView.swift
//  Distributed-Social
//

import SwiftUI

struct PlaylistDetailView: View {
    @Environment(PlayerViewModel.self) private var playerVM
    @Environment(ThemeStore.self) private var themeStore
    let playlist: Playlist

    @State private var searchText = ""

    private var theme: AppTheme { themeStore.theme }

    /// Rows matching the in-playlist search (all rows when not searching).
    private func visibleItems(in sorted: [PlaylistItem]) -> [PlaylistItem] {
        guard !searchText.isEmpty else { return sorted }
        return sorted.filter { pi in
            guard let item = pi.mediaItem else { return false }
            return item.displayName.localizedCaseInsensitiveContains(searchText)
                || (item.artist?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private var totalDuration: TimeInterval {
        (playlist.orderedItems ?? []).compactMap { $0.mediaItem?.duration }.reduce(0, +)
    }

    var body: some View {
        // One sort per render — the list and header both need the ordered rows.
        let sortedItems = playlist.sortedItems
        let visibleItems = visibleItems(in: sortedItems)
        List {
            if sortedItems.isEmpty {
                ContentUnavailableView(
                    "Empty Playlist",
                    systemImage: "list.bullet",
                    description: Text("Add songs via the library's context menu.")
                )
            } else {
                Section {
                    ForEach(visibleItems) { pi in
                        if let item = pi.mediaItem {
                            PlaylistDetailRowView(pi: pi, item: item) {
                                let queue = playableQueue
                                registerPlay(of: item)
                                playerVM.play(item: item, in: queue)
                            }
                        }
                    }
                } header: {
                    Text("\(sortedItems.count) song\(sortedItems.count == 1 ? "" : "s") · \(formattedTotal)")
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, 120, for: .scrollContent)
        .summerBackground()
        .navigationTitle(playlist.name)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search in playlist")
    }

    // MARK: - Helpers

    /// Songs in playlist order whose files still exist. Evaluated on tap, not during render.
    private var playableQueue: [MediaItem] {
        playlist.sortedItems.compactMap { $0.mediaItem }.filter { !$0.isFileMissing }
    }

    private var formattedTotal: String {
        let minutes = Int(totalDuration / 60)
        if minutes >= 60 {
            return "\(minutes / 60) hr \(minutes % 60) min"
        }
        return "\(minutes) min"
    }

    /// Records playback stats used by the Home page and marks this playlist as
    /// the one currently playing. Play count increments once per session.
    private func registerPlay(of item: MediaItem) {
        playlist.lastPlayedItemId = item.id
        playlist.lastPlayedDate = Date()
        if playerVM.currentPlaylistID != playlist.id {
            playlist.playCount += 1
        }
        playerVM.currentPlaylistID = playlist.id
    }
}

// MARK: - Row view

/// Isolated row that reads playerVM directly, so PlaylistDetailView.body
/// is not re-evaluated (and sortedItems not re-sorted) on every play/pause.
private struct PlaylistDetailRowView: View {
    let pi: PlaylistItem
    let item: MediaItem
    let onPlay: () -> Void

    @Environment(PlayerViewModel.self) private var playerVM
    @Environment(ThemeStore.self) private var themeStore

    private var theme: AppTheme { themeStore.theme }
    private var isCurrent: Bool { playerVM.currentItem?.id == item.id }
    private var isMissing: Bool { item.isFileMissing }

    var body: some View {
        HStack(spacing: 10) {
            Text("\(pi.sortOrder + 1)")
                .foregroundStyle(theme.textSecondary)
                .frame(width: 24)
            MediaArtworkView(item: item, size: 44)
                .saturation(isMissing ? 0 : 1)
                .opacity(isMissing ? 0.4 : 1)
            VStack(alignment: .leading, spacing: 2) {
                MarqueeText(
                    text: item.displayName,
                    font: .body.weight(isCurrent ? .semibold : .regular),
                    color: isMissing ? .gray : (isCurrent ? theme.textHighlight : theme.textPrimary)
                )
                if isMissing {
                    Text("File no longer available")
                        .font(.caption)
                        .foregroundStyle(Color.gray)
                } else if let artist = item.artist {
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
            Text(item.duration.formattedTime)
                .font(.caption)
                .foregroundStyle(isMissing ? Color.gray : theme.textSecondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isMissing else { return }
            onPlay()
        }
        .swipeToQueue(enabled: !isMissing) {
            playerVM.addToQueue(item)
        }
        .listRowBackground(Color.clear)
    }
}
