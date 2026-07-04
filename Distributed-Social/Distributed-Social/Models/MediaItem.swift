//
//  MediaItem.swift
//  Distributed-Social
//

import SwiftData
import Foundation

@Model
final class MediaItem {
    var id: UUID = UUID()
    var displayName: String = ""
    var filename: String = ""          // relative to Documents/Media/ — never store absolute path
    var mediaTypeRaw: String = MediaType.audio.rawValue
    var duration: TimeInterval = 0
    var dateImported: Date = Date()
    var lastPosition: TimeInterval = 0
    var isFavorite: Bool = false
    var folder: Folder?
    var playlistItems: [PlaylistItem]?

    var mediaType: MediaType {
        get { MediaType(rawValue: mediaTypeRaw) ?? .audio }
        set { mediaTypeRaw = newValue.rawValue }
    }

    /// Derived at runtime so the library survives reinstalls / OS updates.
    var localURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(Constants.Directories.media)
            .appendingPathComponent(filename)
    }

    init(displayName: String, filename: String, mediaType: MediaType,
         duration: TimeInterval, dateImported: Date = Date()) {
        self.id = UUID()
        self.displayName = displayName
        self.filename = filename
        self.mediaTypeRaw = mediaType.rawValue
        self.duration = duration
        self.dateImported = dateImported
        self.lastPosition = 0
    }
}
