//
//  ContentView.swift
//  Distributed-Social
//
//  Root tab navigation with a mini-player overlay above the tab bar.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var playerVM: PlayerViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                AudioLibraryView()
                    .tabItem { Label("Audio", systemImage: "music.note.list") }
                VideoLibraryView()
                    .tabItem { Label("Video", systemImage: "film") }
                PlaylistsView()
                    .tabItem { Label("Playlists", systemImage: "list.bullet") }
                ImportView()
                    .tabItem { Label("Import", systemImage: "square.and.arrow.down") }
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gear") }
            }

            if playerVM.currentItem != nil {
                MiniPlayerView()
                    .padding(.bottom, 49) // clear the tab bar
            }
        }
        .sheet(isPresented: $playerVM.isFullPlayerPresented) {
            FullPlayerView()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(PlayerViewModel(playbackService: PlaybackService()))
        .environmentObject(MediaLibraryService())
}
