//
//  AddToPlaylistSheet.swift
//  Distributed-Social
//
//  Grid of playlist tiles — identical look to PlaylistsView — with
//  multi-select so songs can be added to one or more playlists at once.
//

import SwiftUI
import SwiftData

struct AddToPlaylistSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(MediaLibraryService.self) private var mediaLibraryService
    @Environment(ThemeStore.self) private var themeStore
    @Query(sort: \Playlist.name) private var playlists: [Playlist]

    private let items: [MediaItem]
    @State private var selectedPlaylistIDs: Set<UUID> = []

    init(item: MediaItem) {
        self.items = [item]
    }

    init(items: [MediaItem]) {
        self.items = items
    }

    private var audioPlaylists: [Playlist] {
        playlists.filter { $0.mediaType == .audio }
    }

    private var theme: AppTheme { themeStore.theme }

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    private var confirmLabel: String {
        switch selectedPlaylistIDs.count {
        case 0:  return "Add"
        case 1:  return "Add to Playlist"
        default: return "Add to \(selectedPlaylistIDs.count) Playlists"
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if audioPlaylists.isEmpty {
                    ContentUnavailableView(
                        "No Playlists",
                        systemImage: "list.bullet",
                        description: Text("Create a playlist first from the Playlists tab.")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(audioPlaylists) { playlist in
                                let isSelected = selectedPlaylistIDs.contains(playlist.id)
                                Button {
                                    if isSelected {
                                        selectedPlaylistIDs.remove(playlist.id)
                                    } else {
                                        selectedPlaylistIDs.insert(playlist.id)
                                    }
                                } label: {
                                    ZStack(alignment: .topLeading) {
                                        PlaylistTileView(playlist: playlist)
                                            .opacity(isSelected ? 1.0 : 0.65)

                                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                            .font(.title2)
                                            .foregroundStyle(isSelected ? Color.blue : theme.textSecondary)
                                            .padding(6)
                                            .background(.ultraThinMaterial, in: Circle())
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                    }
                }
            }
            .summerBackground()
            .navigationTitle(items.count == 1 ? "Add to Playlist" : "Add \(items.count) Songs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(confirmLabel) {
                        addItemsToSelectedPlaylists()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedPlaylistIDs.isEmpty)
                }
            }
        }
    }

    private func addItemsToSelectedPlaylists() {
        let targets = audioPlaylists.filter { selectedPlaylistIDs.contains($0.id) }
        for playlist in targets {
            let existing = Set((playlist.orderedItems ?? []).compactMap { $0.mediaItem?.id })
            for item in items where !existing.contains(item.id) {
                mediaLibraryService.addItem(item, toPlaylist: playlist, in: modelContext)
            }
        }
    }
}
