//
//  VideoLibraryView.swift
//  Distributed-Social
//

import SwiftUI
import SwiftData

struct VideoLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var mediaLibraryService: MediaLibraryService
    @Query(sort: \MediaItem.dateImported, order: .reverse) private var allItems: [MediaItem]
    @Query(sort: \Folder.name) private var folders: [Folder]
    @StateObject private var viewModel = VideoLibraryViewModel()

    @State private var itemForPlaylist: MediaItem?

    var body: some View {
        NavigationStack {
            let items = viewModel.filteredItems(allItems)

            Group {
                if items.isEmpty {
                    ContentUnavailableView(
                        "No Video Files",
                        systemImage: "film",
                        description: Text("Import MP4 or MOV files from the Import tab.")
                    )
                } else {
                    List(items) { item in
                        VideoRowView(item: item) {
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
            .navigationTitle("Video")
            .searchable(text: $viewModel.searchText)
            .sheet(item: $itemForPlaylist) { item in
                AddToPlaylistSheet(item: item)
            }
        }
    }
}
