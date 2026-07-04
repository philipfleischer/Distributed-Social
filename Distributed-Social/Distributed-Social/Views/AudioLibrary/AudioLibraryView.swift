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
        NavigationStack {
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
                        AudioRowView(item: item) {
                            playerVM.play(item: item, in: items)
                        }
                        .listRowBackground(Color.clear)
                        .contextMenu {
                            MediaItemContextMenu(
                                item: item,
                                folders: folders,
                                onAddToPlaylist: { itemForPlaylist = item },
                                onMoveToFolder: { folder in
                                    item.folder = folder
                                },
                                onDelete: {
                                    mediaLibraryService.deleteMediaItem(
                                        item, fileImportService: FileImportService(), in: modelContext)
                                }
                            )
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                mediaLibraryService.deleteMediaItem(
                                    item, fileImportService: FileImportService(), in: modelContext)
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
    }
}

/// Shared context-menu content for a media item in the audio/video libraries.
struct MediaItemContextMenu: View {
    let item: MediaItem
    let folders: [Folder]
    let onAddToPlaylist: () -> Void
    let onMoveToFolder: (Folder?) -> Void
    let onDelete: () -> Void

    var body: some View {
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
