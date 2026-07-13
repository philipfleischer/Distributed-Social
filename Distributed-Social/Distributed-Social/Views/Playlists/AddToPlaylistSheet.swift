//
//  AddToPlaylistSheet.swift
//  Distributed-Social
//

import SwiftUI
import SwiftData

struct AddToPlaylistSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var mediaLibraryService: MediaLibraryService
    @Query(sort: \Playlist.name) private var playlists: [Playlist]

    let item: MediaItem

    private var matchingPlaylists: [Playlist] {
        playlists.filter { $0.mediaType == item.mediaType }
    }

    /// Playlists that already contain this song — shown with a checkmark
    /// instead of an add button so it can't be added twice.
    private var containingPlaylistIDs: Set<UUID> {
        Set((item.playlistItems ?? []).compactMap { $0.playlist?.id })
    }

    var body: some View {
        NavigationStack {
            Group {
                if matchingPlaylists.isEmpty {
                    ContentUnavailableView(
                        "No Playlists",
                        systemImage: "list.bullet",
                        description: Text("Create a \(item.mediaType == .audio ? "audio" : "video") playlist first from the Playlists tab.")
                    )
                } else {
                    List(matchingPlaylists) { playlist in
                        let alreadyIn = containingPlaylistIDs.contains(playlist.id)
                        Button {
                            mediaLibraryService.addItem(item, toPlaylist: playlist, in: modelContext)
                            dismiss()
                        } label: {
                            HStack {
                                Text(playlist.name)
                                Spacer()
                                Image(systemName: alreadyIn ? "checkmark.circle.fill" : "plus.circle")
                                    .foregroundStyle(alreadyIn ? Color.secondary : Color.skyBlue)
                            }
                        }
                        .disabled(alreadyIn)
                    }
                }
            }
            .navigationTitle("Add to Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
