//
//  VideoLibraryView.swift
//  Distributed-Social
//

import SwiftUI
import SwiftData

struct VideoLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(PlayerViewModel.self) private var playerVM
    @EnvironmentObject var mediaLibraryService: MediaLibraryService
    @Query(sort: \MediaItem.dateImported, order: .reverse) private var allItems: [MediaItem]
    @StateObject private var viewModel = VideoLibraryViewModel()

    @State private var itemForPlaylist: MediaItem?

    var body: some View {
        let items = viewModel.filteredItems(allItems)

        Group {
            if items.isEmpty {
                ContentUnavailableView(
                    "No Video Files",
                    systemImage: "film",
                    description: Text("Import MP4 or MOV files from Settings → Import.")
                )
            } else {
                List(items) { item in
                    let isMissing = item.isFileMissing
                    let isCurrent = playerVM.currentItem?.id == item.id
                    VideoRowView(
                        item: item,
                        isCurrent: isCurrent,
                        // Scoped to the row: play/pause then only re-renders
                        // the current row, not the whole list.
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
                .contentMargins(.bottom, 120, for: .scrollContent) // clear the mini player
            }
        }
        .summerBackground()
        .navigationTitle("Video")
        .searchable(text: $viewModel.searchText)
        .sheet(item: $itemForPlaylist) { item in
            AddToPlaylistSheet(item: item)
        }
    }

    /// Tapping the current item toggles play/pause; any other item starts playing.
    private func handlePlay(_ item: MediaItem, in items: [MediaItem]) {
        if playerVM.currentItem?.id == item.id {
            playerVM.togglePlayPause()
        } else {
            playerVM.currentPlaylistID = nil // playing from the library, not a playlist
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
