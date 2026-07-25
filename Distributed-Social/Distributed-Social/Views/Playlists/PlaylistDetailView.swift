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
                            row(for: pi, item: item)
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
        .searchable(text: $searchText, prompt: "Search in playlist")
    }

    // MARK: - Rows

    @ViewBuilder
    private func row(for pi: PlaylistItem, item: MediaItem) -> some View {
        let isCurrent = playerVM.currentItem?.id == item.id
        let isMissing = item.isFileMissing
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
            let queue = playableQueue
            registerPlay(of: item)
            playerVM.play(item: item, in: queue)
        }
        .swipeToQueue(enabled: !isMissing) {
            playerVM.addToQueue(item)
        }
        .listRowBackground(Color.clear)
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
