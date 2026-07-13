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
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(fileImportService: deps.fileImportService)
                .environment(deps.playerViewModel)
                .environment(deps.playbackTimeModel)
                .environmentObject(deps.mediaLibraryService)
                .environmentObject(themeStore)
                .tint(themeStore.theme.textPrimary)
                .preferredColorScheme(themeStore.theme.colorScheme)
                .onChange(of: scenePhase) { _, phase in
                    // Files can be deleted (Files app) only while we're in
                    // the background — recheck cached missing-file states.
                    if phase == .active {
                        MediaItem.fileCheckGeneration &+= 1
                    }
                }
        }
        .modelContainer(for: [MediaItem.self, Playlist.self, PlaylistItem.self, Folder.self])
    }
}
