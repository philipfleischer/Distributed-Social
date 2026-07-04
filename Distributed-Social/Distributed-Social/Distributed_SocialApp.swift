//
//  Distributed_SocialApp.swift
//  Distributed-Social
//
//  Created by Philip Fleischer on 26/06/2026.
//

import SwiftUI
import SwiftData

@main
struct Distributed_SocialApp: App {
    private let deps = AppDependencies()
    @StateObject private var themeStore = ThemeStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(deps.playerViewModel)
                .environmentObject(deps.mediaLibraryService)
                .environmentObject(themeStore)
                .tint(themeStore.theme.textPrimary)
                .preferredColorScheme(themeStore.theme.colorScheme)
        }
        .modelContainer(for: [MediaItem.self, Playlist.self, PlaylistItem.self, Folder.self])
    }
}
