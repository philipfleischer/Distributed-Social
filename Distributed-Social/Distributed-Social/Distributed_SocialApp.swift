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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(deps.playerViewModel)
                .environmentObject(deps.mediaLibraryService)
                .tint(.skyBlue)
                .preferredColorScheme(.dark) // black theme with light-blue text
        }
        .modelContainer(for: [MediaItem.self, Playlist.self, PlaylistItem.self, Folder.self])
    }
}
