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
    @State private var isSelectMode = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var bulkPlaylistItems: [MediaItem] = []
    @State private var showBulkPlaylistSheet = false
    /// Cached sort result — avoids re-sorting on every @State change (e.g.
    /// each checkbox toggle in select mode). Falls back to a live sort until
    /// onAppear populates the cache.
    @State private var sortedItemsCache: [PlaylistItem] = []

    private var theme: AppTheme { themeStore.theme }

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
        let sortedItems = sortedItemsCache.isEmpty ? playlist.sortedItems : sortedItemsCache
        let visibleItems = visibleItems(in: sortedItems)
        let visibleMediaItems = visibleItems.compactMap(\.mediaItem)
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
                            if isSelectMode {
                                selectRow(for: item)
                            } else {
                                PlaylistDetailRowView(pi: pi, item: item) {
                                    let queue = playableQueue
                                    registerPlay(of: item)
                                    playerVM.play(item: item, in: queue)
                                }
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
        .toolbar {
            if isSelectMode {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        isSelectMode = false
                        selectedIDs = []
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    let allSelected = !visibleMediaItems.isEmpty && selectedIDs.count == visibleMediaItems.count
                    Button(allSelected ? "Deselect All" : "Select All") {
                        selectedIDs = allSelected ? [] : Set(visibleMediaItems.map(\.id))
                    }
                }
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Select") { isSelectMode = true }
                        .disabled(sortedItems.isEmpty)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isSelectMode && !selectedIDs.isEmpty {
                selectionActionBar
            }
        }
        .onAppear { sortedItemsCache = playlist.sortedItems }
        .onChange(of: playlist.orderedItems?.count ?? 0) { _, _ in
            sortedItemsCache = playlist.sortedItems
        }
        .onChange(of: searchText) { _, _ in
            if isSelectMode { selectedIDs = [] }
        }
        .onChange(of: showBulkPlaylistSheet) { _, isShowing in
            if !isShowing {
                isSelectMode = false
                selectedIDs = []
            }
        }
        .sheet(isPresented: $showBulkPlaylistSheet) {
            AddToPlaylistSheet(items: bulkPlaylistItems)
        }
    }

    // MARK: - Select-mode row

    @ViewBuilder
    private func selectRow(for item: MediaItem) -> some View {
        let isSelected = selectedIDs.contains(item.id)
        let isMissing = item.isFileMissing
        Button {
            if isSelected { selectedIDs.remove(item.id) }
            else { selectedIDs.insert(item.id) }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.blue : theme.textSecondary)
                MediaArtworkView(item: item, size: 44)
                    .saturation(isMissing ? 0 : 1)
                    .opacity(isMissing ? 0.4 : 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayName)
                        .font(.headline)
                        .foregroundStyle(isMissing ? Color.gray : theme.textPrimary)
                        .lineLimit(1)
                    if let artist = item.artist {
                        Text(artist)
                            .font(.subheadline)
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Text(item.duration.formattedTime)
                    .font(.subheadline)
                    .foregroundStyle(isMissing ? Color.gray : theme.textSecondary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isMissing)
        .listRowBackground(Color.clear)
    }

    // MARK: - Selection action bar

    private var selectionActionBar: some View {
        let playable = playlist.sortedItems
            .compactMap(\.mediaItem)
            .filter { selectedIDs.contains($0.id) && !$0.isFileMissing }
        return HStack(spacing: 24) {
            Text("\(selectedIDs.count) selected")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Button {
                playable.forEach { playerVM.addToQueue($0) }
                isSelectMode = false
                selectedIDs = []
            } label: {
                Label("Queue", systemImage: "text.append")
                    .font(.subheadline.weight(.medium))
            }
            .disabled(playable.isEmpty)
            Button {
                bulkPlaylistItems = playable
                showBulkPlaylistSheet = true
            } label: {
                Label("Playlist", systemImage: "text.badge.plus")
                    .font(.subheadline.weight(.medium))
            }
            .disabled(playable.isEmpty)
        }
        .foregroundStyle(theme.textPrimary)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider() }
    }

    // MARK: - Helpers

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
