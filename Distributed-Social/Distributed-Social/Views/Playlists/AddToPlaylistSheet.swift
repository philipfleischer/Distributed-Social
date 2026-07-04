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
                        Button {
                            mediaLibraryService.addItem(item, toPlaylist: playlist, in: modelContext)
                            dismiss()
                        } label: {
                            HStack {
                                Text(playlist.name)
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(Color.skyBlue)
                            }
                        }
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
