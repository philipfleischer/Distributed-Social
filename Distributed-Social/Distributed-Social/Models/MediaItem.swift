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
    var filename: String = ""
    var mediaTypeRaw: String = MediaType.audio.rawValue
    var duration: TimeInterval = 0
    var dateImported: Date = Date()
    var lastPosition: TimeInterval = 0
    var isFavorite: Bool = false
    var artist: String?
    @Attribute(.externalStorage) var artworkData: Data?
    var folder: Folder?
    var playlistItems: [PlaylistItem]?

    var mediaType: MediaType {
        get { MediaType(rawValue: mediaTypeRaw) ?? .audio }
        set { mediaTypeRaw = newValue.rawValue }
    }

    /// Bumped when the app returns to the foreground so the cached
    /// missing-file checks are re-verified.
    static var fileCheckGeneration: Int = 0

    @Transient private var missingCheckGeneration: Int = -1
    @Transient private var missingCached: Bool = false

    var isFileMissing: Bool {
        if missingCheckGeneration != MediaItem.fileCheckGeneration {
            missingCached = !FileManager.default.fileExists(atPath: localURL.path)
            missingCheckGeneration = MediaItem.fileCheckGeneration
        }
        return missingCached
    }

    var localURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(Constants.Directories.media)
            .appendingPathComponent(filename)
    }

    init(displayName: String, filename: String, mediaType: MediaType,
         duration: TimeInterval, dateImported: Date = Date(),
         artist: String? = nil, artworkData: Data? = nil) {
        self.id = UUID()
        self.displayName = displayName
        self.filename = filename
        self.mediaTypeRaw = mediaType.rawValue
        self.duration = duration
        self.dateImported = dateImported
        self.lastPosition = 0
        self.artist = artist
        self.artworkData = artworkData
    }
}
