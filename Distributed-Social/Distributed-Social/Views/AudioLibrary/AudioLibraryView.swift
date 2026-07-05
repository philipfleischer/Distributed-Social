//
//  AudioLibraryView.swift
//  Distributed-Social
//

import SwiftUI
import SwiftData

struct AudioLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var mediaLibraryService: MediaLibraryService
    @Query(sort: \MediaItem.dateImported, order: .reverse) private var allItems: [MediaItem]
    @Query(sort: \Folder.name) private var folders: [Folder]
    @StateObject private var viewModel = AudioLibraryViewModel()

    @State private var itemForPlaylist: MediaItem?

    var body: some View {
        let items = viewModel.filteredItems(allItems)

        Group {
                if items.isEmpty {
                    ContentUnavailableView(
                        "No Audio Files",
                        systemImage: "music.note.list",
                        description: Text("Import MP3, M4A, or WAV files from the Import tab.")
                    )
                } else {
                    List(items) { item in
                        AudioRowView(
                            item: item,
                            isCurrent: playerVM.currentItem?.id == item.id,
                            isPlaying: playerVM.isPlaying,
                            onPlay: { handlePlay(item, in: items) }
                        ) {
                            menu(for: item)
                        }
                        .listRowBackground(Color.clear)
                        .contextMenu { menu(for: item) }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                delete(item)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                .scrollContentBackground(.hidden)
            }
        }
        .summerBackground()
        .navigationTitle("Audio")
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
        mediaLibraryService.deleteMediaItem(
            item, fileImportService: FileImportService(), in: modelContext)
    }

    @ViewBuilder
    private func menu(for item: MediaItem) -> some View {
        MediaItemContextMenu(
            item: item,
            folders: folders,
            onPlayNext: { playerVM.playNext(item) },
            onAddToQueue: { playerVM.addToQueue(item) },
            onAddToPlaylist: { itemForPlaylist = item },
            onMoveToFolder: { folder in item.folder = folder },
            onDelete: { delete(item) }
        )
    }
}

/// Shared menu content for a media item in the audio/video libraries
/// (used by both the "⋮" button and the long-press context menu).
struct MediaItemContextMenu: View {
    let item: MediaItem
    let folders: [Folder]
    let onPlayNext: () -> Void
    let onAddToQueue: () -> Void
    let onAddToPlaylist: () -> Void
    let onMoveToFolder: (Folder?) -> Void
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
        Menu {
            ForEach(folders) { folder in
                Button { onMoveToFolder(folder) } label: {
                    Label(folder.name, systemImage: item.folder?.id == folder.id ? "checkmark" : "folder")
                }
            }
            if item.folder != nil {
                Divider()
                Button { onMoveToFolder(nil) } label: {
                    Label("Remove from Folder", systemImage: "folder.badge.minus")
                }
            }
        } label: {
            Label("Move to Folder", systemImage: "folder")
        }
        Divider()
        Button(role: .destructive) { onDelete() } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}
