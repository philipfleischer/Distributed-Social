//
//  PlaylistsView.swift
//  Distributed-Social
//

import SwiftUI
import SwiftData

struct PlaylistsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var mediaLibraryService: MediaLibraryService
    @Query(sort: \Playlist.name) private var playlists: [Playlist]
    @State private var showCreateSheet = false
    @State private var newName = ""
    @State private var newType: MediaType = .audio

    var body: some View {
        NavigationStack {
            List {
                Section("Audio Playlists") {
                    ForEach(playlists.filter { $0.mediaType == .audio }) { playlist in
                        NavigationLink(playlist.name) {
                            PlaylistDetailView(playlist: playlist)
                        }
                    }
                    .onDelete { offsets in
                        delete(offsets, in: playlists.filter { $0.mediaType == .audio })
                    }
                }
                Section("Video Playlists") {
                    ForEach(playlists.filter { $0.mediaType == .video }) { playlist in
                        NavigationLink(playlist.name) {
                            PlaylistDetailView(playlist: playlist)
                        }
                    }
                    .onDelete { offsets in
                        delete(offsets, in: playlists.filter { $0.mediaType == .video })
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .summerBackground()
            .navigationTitle("Playlists")
            .toolbar {
                Button { showCreateSheet = true } label: {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                createSheet
            }
        }
    }

    private var createSheet: some View {
        NavigationStack {
            Form {
                TextField("Playlist Name", text: $newName)
                Picker("Type", selection: $newType) {
                    Text("Audio").tag(MediaType.audio)
                    Text("Video").tag(MediaType.video)
                }
            }
            .navigationTitle("New Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        mediaLibraryService.createPlaylist(
                            name: newName, mediaType: newType, in: modelContext)
                        showCreateSheet = false
                        newName = ""
                    }
                    .disabled(newName.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showCreateSheet = false; newName = "" }
                }
            }
        }
    }

    private func delete(_ offsets: IndexSet, in list: [Playlist]) {
        for i in offsets {
            modelContext.delete(list[i])
        }
    }
}
