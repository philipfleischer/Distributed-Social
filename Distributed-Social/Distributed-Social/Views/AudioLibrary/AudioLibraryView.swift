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
    @Query(filter: #Predicate<MediaItem> { $0.mediaTypeRaw == "audio" },
           sort: \MediaItem.dateImported, order: .reverse) private var allItems: [MediaItem]
    @State private var viewModel = AudioLibraryViewModel()

    @State private var itemForPlaylist: MediaItem?

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
                List(items) { item in
                    let isMissing = item.isFileMissing
                    let isCurrent = playerVM.currentItem?.id == item.id
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
                .scrollContentBackground(.hidden)
                .contentMargins(.bottom, 120, for: .scrollContent)
            }
        }
        .summerBackground()
        .navigationTitle("Audio")
        .searchable(text: $viewModel.searchText)
        .toolbar {
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
        .sheet(item: $itemForPlaylist) { item in
            AddToPlaylistSheet(item: item)
        }
    }

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
