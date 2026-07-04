//
//  PlaylistsView.swift
//  Distributed-Social
//
//  Two-column grid of playlist cover tiles. Long-press a tile to choose a
//  custom cover image or delete the playlist.
//

import SwiftUI
import SwiftData
import PhotosUI

struct PlaylistsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var mediaLibraryService: MediaLibraryService
    @EnvironmentObject var playerVM: PlayerViewModel
    @Query(sort: \Playlist.name) private var playlists: [Playlist]

    @State private var showCreateSheet = false
    @State private var newName = ""
    @State private var newType: MediaType = .audio

    @State private var playlistForImage: Playlist?
    @State private var showImagePicker = false
    @State private var pickedImage: PhotosPickerItem?

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if playlists.isEmpty {
                        ContentUnavailableView(
                            "No Playlists",
                            systemImage: "list.bullet",
                            description: Text("Tap + to create your first playlist.")
                        )
                        .padding(.top, 80)
                    } else {
                        section(title: "Audio Playlists", items: playlists.filter { $0.mediaType == .audio })
                        section(title: "Video Playlists", items: playlists.filter { $0.mediaType == .video })
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 120) // clear the mini player
            }
            .summerBackground()
            .navigationTitle("Playlists")
            .toolbar {
                Button { showCreateSheet = true } label: {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showCreateSheet) { createSheet }
            .photosPicker(isPresented: $showImagePicker, selection: $pickedImage, matching: .images)
            .onChange(of: pickedImage) { _, newValue in
                guard let newValue, let target = playlistForImage else { return }
                Task {
                    if let data = try? await newValue.loadTransferable(type: Data.self) {
                        target.imageData = data
                    }
                    pickedImage = nil
                    playlistForImage = nil
                }
            }
        }
    }

    @ViewBuilder
    private func section(title: String, items: [Playlist]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.title2).fontWeight(.semibold)
                    .foregroundStyle(Color.skyBlue)

                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(items) { playlist in
                        NavigationLink {
                            PlaylistDetailView(playlist: playlist)
                        } label: {
                            PlaylistTileView(
                                playlist: playlist,
                                isActive: playerVM.currentPlaylistID == playlist.id
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                playlistForImage = playlist
                                showImagePicker = true
                            } label: {
                                Label("Choose Cover Image", systemImage: "photo")
                            }
                            if playlist.imageData != nil {
                                Button {
                                    playlist.imageData = nil
                                } label: {
                                    Label("Remove Cover Image", systemImage: "photo.badge.exclamationmark")
                                }
                            }
                            Divider()
                            Button(role: .destructive) {
                                modelContext.delete(playlist)
                            } label: {
                                Label("Delete Playlist", systemImage: "trash")
                            }
                        }
                    }
                }
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
}
