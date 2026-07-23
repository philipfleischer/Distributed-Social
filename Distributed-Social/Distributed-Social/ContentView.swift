//
//  ContentView.swift
//  Distributed-Social
//
//  Root tab navigation. The full player is an overlay (not a sheet) so the
//  tab bar stays visible and usable on every screen; switching tabs
//  collapses the player back to the mini player.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(PlayerViewModel.self) private var playerVM
    @Environment(MediaLibraryService.self) private var mediaLibraryService
    let fileImportService: FileImportServiceProtocol
    @State private var selectedTab = 0
    /// Shared namespace for the artwork hero animation between the mini player
    /// and the full player.
    @Namespace private var artworkNamespace

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem { Label("Home", systemImage: "house.fill") }
                    .tag(0)
                PlaylistsView()
                    .tabItem { Label("Playlists", systemImage: "list.bullet") }
                    .tag(1)
                SettingsView(fileImportService: fileImportService)
                    .tabItem { Label("Settings", systemImage: "gear") }
                    .tag(2)
            }

            // Mini player: always in the hierarchy when something is loaded so
            // matchedGeometryEffect can animate between it and the full player.
            if playerVM.currentItem != nil {
                MiniPlayerView(artworkNamespace: artworkNamespace)
                    .padding(.bottom, 64)
                    .opacity(playerVM.isFullPlayerPresented ? 0 : 1)
                    .allowsHitTesting(!playerVM.isFullPlayerPresented)
                    .zIndex(0)
            }

            if playerVM.isFullPlayerPresented {
                FullPlayerView(artworkNamespace: artworkNamespace)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .animation(.spring(duration: 0.45), value: playerVM.isFullPlayerPresented)
        .onChange(of: selectedTab) { _, _ in
            playerVM.isFullPlayerPresented = false
        }
        .overlay(alignment: .top) {
            if let toast = playerVM.toast {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                    Text(toast)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(2)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Color.green.opacity(0.92))
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
                .padding(.horizontal, 24)
                .padding(.top, 4)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(2)
            }
        }
        .animation(.spring(duration: 0.3), value: playerVM.toast)
        .task {
            mediaLibraryService.cleanUpOrphanedPlaylistItems(in: modelContext)
            await fileImportService.backfillMetadataIfNeeded(in: modelContext)
            await fileImportService.downscaleArtworkIfNeeded(in: modelContext)
        }
    }
}

#Preview {
    let playbackService = PlaybackService()
    let fileImportService = FileImportService()
    ContentView(fileImportService: fileImportService)
        .environment(PlayerViewModel(playbackService: playbackService))
        .environment(PlaybackTimeModel(playbackService: playbackService))
        .environment(MediaLibraryService(fileImportService: fileImportService))
}
