//
//  ContentView.swift
//  Distributed-Social
//
//  Root tab navigation. The full player is an overlay (not a sheet) so the
//  tab bar stays visible and usable on every screen.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var playerVM: PlayerViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                HomeView()
                    .tabItem { Label("Home", systemImage: "house.fill") }
                PlaylistsView()
                    .tabItem { Label("Playlists", systemImage: "list.bullet") }
                ImportView()
                    .tabItem { Label("Import", systemImage: "square.and.arrow.down") }
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gear") }
            }

            if playerVM.isFullPlayerPresented {
                FullPlayerView()
                    .padding(.bottom, 49) // keep the tab bar visible below
                    .transition(.move(edge: .bottom))
                    .zIndex(1)
            } else if playerVM.currentItem != nil {
                MiniPlayerView()
                    .padding(.bottom, 64) // sit clearly above the tab bar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: playerVM.isFullPlayerPresented)
    }
}

#Preview {
    ContentView()
        .environmentObject(PlayerViewModel(playbackService: PlaybackService()))
        .environmentObject(MediaLibraryService())
}
