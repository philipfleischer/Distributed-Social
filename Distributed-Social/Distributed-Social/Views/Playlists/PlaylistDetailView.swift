//
//  PlaylistDetailView.swift
//  Distributed-Social
//

import SwiftUI
import SwiftData

struct PlaylistDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(PlayerViewModel.self) private var playerVM
    @EnvironmentObject var themeStore: ThemeStore
    let playlist: Playlist

    @State private var searchText = ""
    @State private var showAddSongs = false

    private var theme: AppTheme { themeStore.theme }

    private var sortedItems: [PlaylistItem] {
        playlist.sortedItems
    }

    /// Rows matching the in-playlist search (all rows when not searching).
    private var visibleItems: [PlaylistItem] {
        guard !searchText.isEmpty else { return sortedItems }
        return sortedItems.filter { pi in
            guard let item = pi.mediaItem else { return false }
            return item.displayName.localizedCaseInsensitiveContains(searchText)
                || (item.artist?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private var totalDuration: TimeInterval {
        // Summing doesn't need the sorted order — skip the sort.
        (playlist.orderedItems ?? []).compactMap { $0.mediaItem?.duration }.reduce(0, +)
    }

    var body: some View {
        List {
            if sortedItems.isEmpty {
                ContentUnavailableView(
                    "Empty Playlist",
                    systemImage: "list.bullet",
                    description: Text("Tap + to add songs from your library.")
                )
            } else {
                Section {
                    ForEach(visibleItems) { pi in
                        if let item = pi.mediaItem {
                            row(for: pi, item: item)
                        }
                    }
                    .onDelete { offsets in
                        for i in offsets {
                            modelContext.delete(visibleItems[i])
                        }
                        renumber()
                    }
                    .onMove { from, to in
                        moveItems(from: from, to: to)
                    }
                    // Disabled while searching: the drag indices refer to
                    // the filtered rows and would move the wrong songs.
                    .moveDisabled(!searchText.isEmpty)
                } header: {
                    Text("\(sortedItems.count) song\(sortedItems.count == 1 ? "" : "s") · \(formattedTotal)")
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, 120, for: .scrollContent) // clear the mini player
        .summerBackground()
        .navigationTitle(playlist.name)
        .searchable(text: $searchText, prompt: "Search in playlist")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddSongs = true } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if !sortedItems.isEmpty { EditButton() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if !sortedItems.isEmpty {
                    Button {
                        playOrResume()
                    } label: {
                        Label("Play", systemImage: "play.fill")
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSongs) {
            AddSongsSheet(playlist: playlist)
        }
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

    /// Songs in playlist order whose files still exist.
    private var playableQueue: [MediaItem] {
        sortedItems.compactMap { $0.mediaItem }.filter { !$0.isFileMissing }
    }

    /// The toolbar Play button resumes from the last played song when the
    /// playlist has one, otherwise starts from the top.
    private func playOrResume() {
        let items = playableQueue
        guard !items.isEmpty else { return }
        let startItem = items.first { $0.id == playlist.lastPlayedItemId } ?? items[0]
        registerPlay(of: startItem)
        playerVM.play(item: startItem, in: items)
    }

    private var formattedTotal: String {
        let minutes = Int(totalDuration / 60)
        if minutes >= 60 {
            return "\(minutes / 60) hr \(minutes % 60) min"
        }
        return "\(minutes) min"
    }

    /// Records playback stats used by the Home page (recently played / popular)
    /// and marks this playlist as the one currently playing.
    private func registerPlay(of item: MediaItem) {
        playlist.lastPlayedItemId = item.id
        playlist.lastPlayedDate = Date()
        playlist.playCount += 1
        playerVM.currentPlaylistID = playlist.id
    }

    private func moveItems(from: IndexSet, to: Int) {
        var items = sortedItems
        items.move(fromOffsets: from, toOffset: to)
        for (index, pi) in items.enumerated() {
            pi.sortOrder = index
        }
    }

    private func renumber() {
        for (index, pi) in playlist.sortedItems.enumerated() {
            pi.sortOrder = index
        }
    }
}
