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
    @EnvironmentObject var playerVM: PlayerViewModel
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
                SettingsView()
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
    }
}

#Preview {
    ContentView()
        .environmentObject(PlayerViewModel(playbackService: PlaybackService()))
        .environmentObject(MediaLibraryService())
}
