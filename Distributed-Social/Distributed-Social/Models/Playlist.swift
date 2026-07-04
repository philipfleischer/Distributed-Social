//
//  Playlist.swift
//  Distributed-Social
//

import SwiftData
import Foundation

@Model
final class Playlist {
    var id: UUID = UUID()
    var name: String = ""
    var mediaTypeRaw: String = MediaType.audio.rawValue
    var lastPlayedItemId: UUID?
    var lastPlayedPosition: TimeInterval = 0
    @Relationship(inverse: \PlaylistItem.playlist) var orderedItems: [PlaylistItem]?

    var mediaType: MediaType {
        get { MediaType(rawValue: mediaTypeRaw) ?? .audio }
        set { mediaTypeRaw = newValue.rawValue }
    }

    var sortedItems: [PlaylistItem] {
        (orderedItems ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    init(name: String, mediaType: MediaType) {
        self.id = UUID()
        self.name = name
        self.mediaTypeRaw = mediaType.rawValue
        self.lastPlayedPosition = 0
    }
}
