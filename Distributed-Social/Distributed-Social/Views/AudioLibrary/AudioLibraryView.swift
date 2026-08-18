//
//  AudioLibraryView.swift
//  Distributed-Social
//

import SwiftUI
import SwiftData

struct AudioLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(PlayerViewModel.self) private var playerVM
    @Environment(MediaLibraryService.self) private var mediaLibraryService
    @Environment(ThemeStore.self) private var themeStore
    @Query(filter: #Predicate<MediaItem> { $0.mediaTypeRaw == "audio" },
           sort: \MediaItem.dateImported, order: .reverse) private var allItems: [MediaItem]
    @State private var viewModel = AudioLibraryViewModel()

    @State private var itemForPlaylist: MediaItem?
    @State private var isSelectMode = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var bulkPlaylistItems: [MediaItem] = []
    @State private var showBulkPlaylistSheet = false

    private var theme: AppTheme { themeStore.theme }

    private var selectedPlayableItems: [MediaItem] {
        allItems.filter { selectedIDs.contains($0.id) && !$0.isFileMissing }
    }

    var body: some View {
        let items = viewModel.filteredItems(allItems)

        Group {
            if items.isEmpty {
                ContentUnavailableView(
                    "No Audio Files",
                    systemImage: "music.note.list",
                    description: Text("Import MP3, M4A, or WAV files from Settings → Import.")
                )
            } else {
                List {
                    // Inline select banner shown when search has results
                    if !viewModel.searchText.isEmpty && !isSelectMode {
                        HStack {
                            Text("\(items.count) result\(items.count == 1 ? "" : "s")")
                                .font(.subheadline)
                                .foregroundStyle(theme.textSecondary)
                            Spacer()
                            Button {
                                isSelectMode = true
                            } label: {
                                Label("Select", systemImage: "checkmark.circle")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(theme.textPrimary)
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }

                    ForEach(items) { item in
                        let isMissing = item.isFileMissing
                        let isCurrent = playerVM.currentItem?.id == item.id
                        if isSelectMode {
                            selectRow(for: item)
                        } else {
                            AudioRowView(
                                item: item,
                                isCurrent: isCurrent,
                                isPlaying: isCurrent && playerVM.isPlaying,
                                isMissing: isMissing,
                                onPlay: { handlePlay(item, in: items) }
                            ) {
                                menu(for: item)
                            }
                            .listRowBackground(Color.clear)
                            .contextMenu {
                                if isMissing {
                                    Button(role: .destructive) { delete(item) } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                } else {
                                    menu(for: item)
                                }
                            }
                            .swipeToQueue(enabled: !isMissing) {
                                playerVM.addToQueue(item)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    delete(item)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .contentMargins(.bottom, 120, for: .scrollContent)
            }
        }
        .summerBackground()
        .navigationTitle("Audio")
        .searchable(text: $viewModel.searchText)
        .toolbar {
            if isSelectMode {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        isSelectMode = false
                        selectedIDs = []
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    let allSelected = !items.isEmpty && selectedIDs.count == items.count
                    Button(allSelected ? "Deselect All" : "Select All") {
                        selectedIDs = allSelected ? [] : Set(items.map(\.id))
                    }
                }
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Select") { isSelectMode = true }
                        .disabled(items.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(LibrarySortOrder.allCases) { order in
                            Button {
                                viewModel.sortOrder = order
                            } label: {
                                if viewModel.sortOrder == order {
                                    Label(order.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(order.rawValue)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isSelectMode && !selectedIDs.isEmpty {
                selectionActionBar
            }
        }
        .onChange(of: viewModel.searchText) { _, _ in
            if isSelectMode { selectedIDs = [] }
        }
        .onChange(of: showBulkPlaylistSheet) { _, isShowing in
            if !isShowing {
                isSelectMode = false
                selectedIDs = []
            }
        }
        .sheet(item: $itemForPlaylist) { item in
            AddToPlaylistSheet(item: item)
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
        let playable = selectedPlayableItems
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

    private func handlePlay(_ item: MediaItem, in items: [MediaItem]) {
        if playerVM.currentItem?.id == item.id {
            playerVM.togglePlayPause()
        } else {
            playerVM.currentPlaylistID = nil
            playerVM.play(item: item, in: items)
        }
    }

    private func delete(_ item: MediaItem) {
        mediaLibraryService.deleteMediaItem(item, in: modelContext)
    }

    @ViewBuilder
    private func menu(for item: MediaItem) -> some View {
        MediaItemContextMenu(
            item: item,
            onPlayNext: { playerVM.playNext(item) },
            onAddToQueue: { playerVM.addToQueue(item) },
            onAddToPlaylist: { itemForPlaylist = item },
            onDelete: { delete(item) }
        )
    }
}

/// Shared menu content for a media item in the audio/video libraries
/// (used by both the "⋮" button and the long-press context menu).
struct MediaItemContextMenu: View {
    let item: MediaItem
    let onPlayNext: () -> Void
    let onAddToQueue: () -> Void
    let onAddToPlaylist: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button { onPlayNext() } label: {
            Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
        }
        Button { onAddToQueue() } label: {
            Label("Add to Queue", systemImage: "text.append")
        }
        Divider()
        Button { onAddToPlaylist() } label: {
            Label("Add to Playlist", systemImage: "text.badge.plus")
        }
        Divider()
        Button(role: .destructive) { onDelete() } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}
