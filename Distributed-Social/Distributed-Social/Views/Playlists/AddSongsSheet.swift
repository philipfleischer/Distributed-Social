//
//  AddSongsSheet.swift
//  Distributed-Social
//
//  Adds library songs to a playlist from inside the playlist — the reverse
//  of AddToPlaylistSheet. Songs already in the playlist show a checkmark.
//

import SwiftUI
import SwiftData

struct AddSongsSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(MediaLibraryService.self) private var mediaLibraryService
    @Environment(ThemeStore.self) private var themeStore
    @Query(sort: \MediaItem.dateImported, order: .reverse) private var allItems: [MediaItem]

    let playlist: Playlist
    @State private var searchText = ""

    private var theme: AppTheme { themeStore.theme }

    private var existingIDs: Set<UUID> {
        Set(playlist.sortedItems.compactMap { $0.mediaItem?.id })
    }

    private var candidates: [MediaItem] {
        var items = allItems.filter { $0.mediaType == playlist.mediaType && !$0.isFileMissing }
        if !searchText.isEmpty {
            items = items.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchText)
                    || ($0.artist?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        return items
    }

    var body: some View {
        NavigationStack {
            Group {
                if candidates.isEmpty {
                    ContentUnavailableView(
                        "No Songs to Add",
                        systemImage: playlist.mediaType.systemImage,
                        description: Text("Import files from Settings → Import first.")
                    )
                } else {
                    List(candidates) { item in
                        let alreadyIn = existingIDs.contains(item.id)
                        HStack(spacing: 12) {
                            MediaArtworkView(item: item, size: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.displayName)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(theme.textPrimary)
                                    .lineLimit(1)
                                if let artist = item.artist {
                                    Text(artist)
                                        .font(.caption)
                                        .foregroundStyle(theme.textSecondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            if alreadyIn {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(theme.textSecondary)
                            } else {
                                Button {
                                    mediaLibraryService.addItem(item, toPlaylist: playlist, in: modelContext)
                                    Haptics.light()
                                } label: {
                                    Image(systemName: "plus.circle")
                                        .font(.title3)
                                        .foregroundStyle(theme.textPrimary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .summerBackground()
            .navigationTitle("Add Songs")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
