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
    let fileImportService: FileImportServiceProtocol
    @State private var selectedTab = 0

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

            if playerVM.isFullPlayerPresented {
                FullPlayerView()
                    .transition(.move(edge: .bottom))
                    .zIndex(1)
            } else if playerVM.currentItem != nil {
                MiniPlayerView()
                    .padding(.bottom, 64) // sit clearly above the tab bar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: playerVM.isFullPlayerPresented)
        .onChange(of: selectedTab) { _, _ in
            // Selecting a tab collapses the full player to the mini player.
            playerVM.isFullPlayerPresented = false
        }
        .overlay(alignment: .top) {
            // Confirmation toast for queue actions — visible on every screen.
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
            // Old imports predate tag extraction — fill in their embedded
            // title/artist/cover art once.
            await fileImportService.backfillMetadataIfNeeded(in: modelContext)
        }
    }
}

#Preview {
    let playbackService = PlaybackService()
    let fileImportService = FileImportService()
    ContentView(fileImportService: fileImportService)
        .environment(PlayerViewModel(playbackService: playbackService))
        .environment(PlaybackTimeModel(playbackService: playbackService))
        .environmentObject(MediaLibraryService(fileImportService: fileImportService))
}
