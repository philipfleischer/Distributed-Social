//
//  PlaylistItem.swift
//  Distributed-Social
//

import SwiftData
import Foundation

@Model
final class PlaylistItem {
    var id: UUID = UUID()
    var sortOrder: Int = 0
    var mediaItem: MediaItem?
    var playlist: Playlist?

    init(mediaItem: MediaItem, playlist: Playlist, sortOrder: Int) {
        self.id = UUID()
        self.sortOrder = sortOrder
        self.mediaItem = mediaItem
        self.playlist = playlist
    }
}
