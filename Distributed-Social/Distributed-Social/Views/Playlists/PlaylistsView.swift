//
//  PlaylistsView.swift
//  Distributed-Social
//
//  Two-column grid of playlist tiles. Pinned special tiles (Favourites,
//  All Songs) always appear first. Select mode lets you pick multiple
//  playlists and merge them into a temporary combined playlist.
//

import SwiftUI
import SwiftData
import PhotosUI

struct PlaylistsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(MediaLibraryService.self) private var mediaLibraryService
    @Environment(PlayerViewModel.self) private var playerVM
    @Environment(ThemeStore.self) private var themeStore
    @Query(sort: \Playlist.name) private var playlists: [Playlist]
    @Query(filter: #Predicate<MediaItem> { $0.mediaTypeRaw == "audio" }) private var allAudioItems: [MediaItem]
    @Query(filter: #Predicate<MediaItem> { $0.isFavorite }) private var favorites: [MediaItem]

    @State private var searchText = ""
    @State private var showCreateSheet = false
    @State private var newName = ""

    @State private var playlistForImage: Playlist?
    @State private var showImagePicker = false
    @State private var pickedImage: PhotosPickerItem?

    @State private var playlistToRename: Playlist?
    @State private var renameText = ""

    @State private var isSelectMode = false
    @State private var selectedPlaylists: Set<UUID> = []
    @State private var combinedItems: [MediaItem] = []
    @State private var showCombinedPlaylist = false

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    private var theme: AppTheme { themeStore.theme }

    private var audioPlaylists: [Playlist] {
        playlists.filter { $0.mediaType == .audio }
    }

    private var filteredPlaylists: [Playlist] {
        guard !searchText.isEmpty else { return audioPlaylists }
        return audioPlaylists.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    specialTilesSection
                        .padding(.horizontal)

                    if !searchText.isEmpty && filteredPlaylists.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                            .padding(.top, 40)
                    } else if !filteredPlaylists.isEmpty {
                        regularPlaylistsSection
                            .padding(.horizontal)
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 120)
            }
            .summerBackground()
            .navigationTitle("Playlists")
            .searchable(text: $searchText, prompt: "Playlist name")
            .toolbar {
                if isSelectMode {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") {
                            isSelectMode = false
                            selectedPlaylists = []
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            let selected = audioPlaylists.filter { selectedPlaylists.contains($0.id) }
                            let raw = selected.flatMap { $0.sortedItems.compactMap(\.mediaItem) }
                            var seen = Set<UUID>()
                            combinedItems = raw.filter { seen.insert($0.id).inserted }
                            isSelectMode = false
                            selectedPlaylists = []
                            showCombinedPlaylist = true
                        } label: {
                            Image(systemName: "checkmark")
                        }
                        .disabled(selectedPlaylists.isEmpty)
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Select") { isSelectMode = true }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showCreateSheet = true } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $showCombinedPlaylist) {
                CombinedPlaylistView(items: combinedItems)
            }
            .sheet(isPresented: $showCreateSheet) { createSheet }
            .photosPicker(isPresented: $showImagePicker, selection: $pickedImage, matching: .images)
            .alert("Rename Playlist", isPresented: Binding(
                get: { playlistToRename != nil },
                set: { if !$0 { playlistToRename = nil } }
            )) {
                TextField("Playlist Name", text: $renameText)
                Button("Rename") {
                    if let playlist = playlistToRename, !renameText.isEmpty {
                        playlist.name = renameText
                    }
                    playlistToRename = nil
                }
                Button("Cancel", role: .cancel) { playlistToRename = nil }
            }
            .onChange(of: pickedImage) { _, newValue in
                guard let newValue, let target = playlistForImage else { return }
                Task {
                    if let data = try? await newValue.loadTransferable(type: Data.self) {
                        target.imageData = await ArtworkThumbnailCache.downscaledCoverData(from: data) ?? data
                    }
                    pickedImage = nil
                    playlistForImage = nil
                }
            }
        }
    }

    // MARK: - Special tiles

    private var specialTilesSection: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            NavigationLink {
                FavoritesView()
            } label: {
                specialTile(
                    title: "Favourites",
                    subtitle: "\(favorites.count) song\(favorites.count == 1 ? "" : "s")",
                    content: AnyView(
                        Image(systemName: "heart.fill")
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(.red)
                    ),
                    background: Color.black
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                AudioLibraryView()
            } label: {
                specialTile(
                    title: "All Songs",
                    subtitle: "\(allAudioItems.count) song\(allAudioItems.count == 1 ? "" : "s")",
                    content: AnyView(
                        Image(systemName: "music.note.list")
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(.white)
                    ),
                    background: Color(red: 0.12, green: 0.12, blue: 0.18)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func specialTile(title: String, subtitle: String, content: AnyView, background: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(background)
                content
            }
            .aspectRatio(1, contentMode: .fit)
            .shadow(color: .black.opacity(0.4), radius: 6, y: 3)

            Text(title)
                .font(.headline)
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
        }
    }

    // MARK: - Regular playlists

    private var regularPlaylistsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if isSelectMode {
                Text("Select playlists to combine")
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
            }

            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(filteredPlaylists) { playlist in
                    if isSelectMode {
                        selectableTile(for: playlist)
                    } else {
                        normalTile(for: playlist)
                    }
                }
            }
        }
    }

    private func selectableTile(for playlist: Playlist) -> some View {
        let isSelected = selectedPlaylists.contains(playlist.id)
        return Button {
            if isSelected {
                selectedPlaylists.remove(playlist.id)
            } else {
                selectedPlaylists.insert(playlist.id)
            }
        } label: {
            ZStack(alignment: .topLeading) {
                PlaylistTileView(
                    playlist: playlist,
                    isActive: playerVM.currentPlaylistID == playlist.id
                )
                .opacity(isSelected ? 1.0 : 0.55)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.blue : theme.textSecondary)
                    .padding(6)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
        .buttonStyle(.plain)
    }

    private func normalTile(for playlist: Playlist) -> some View {
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
                renameText = playlist.name
                playlistToRename = playlist
            } label: {
                Label("Rename", systemImage: "pencil")
            }
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
                mediaLibraryService.deletePlaylist(playlist, in: modelContext)
            } label: {
                Label("Delete Playlist", systemImage: "trash")
            }
        }
    }

    // MARK: - Create sheet

    private var createSheet: some View {
        NavigationStack {
            Form {
                TextField("Playlist Name", text: $newName)
            }
            .navigationTitle("New Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        mediaLibraryService.createPlaylist(name: newName, mediaType: .audio, in: modelContext)
                        showCreateSheet = false
                        newName = ""
                    }
                    .disabled(newName.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showCreateSheet = false
                        newName = ""
                    }
                }
            }
        }
    }
}
