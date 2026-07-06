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
    /// How many times playback of this item has started.
    var playCount: Int = 0
    /// Artist name from the file's embedded tags (e.g. Spotify/ID3), if any.
    var artist: String?
    /// Embedded cover art from the file's tags; rows fall back to the
    /// generated gradient artwork when this is nil.
    @Attribute(.externalStorage) var artworkData: Data?
    var folder: Folder?
    var playlistItems: [PlaylistItem]?

    var mediaType: MediaType {
        get { MediaType(rawValue: mediaTypeRaw) ?? .audio }
        set { mediaTypeRaw = newValue.rawValue }
    }

    /// True when the underlying file no longer exists on disk (e.g. deleted
    /// via the Files app). Missing items are shown greyed out and can only
    /// be deleted.
    var isFileMissing: Bool {
        !FileManager.default.fileExists(atPath: localURL.path)
    }

    /// Derived at runtime so the library survives reinstalls / OS updates.
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
