//
//  MediaLibraryServiceProtocol.swift
//  Distributed-Social
//

import SwiftData
import Foundation

protocol MediaLibraryServiceProtocol: AnyObject {
    @discardableResult
    func createPlaylist(name: String, mediaType: MediaType, in context: ModelContext) -> Playlist
    func addItem(_ item: MediaItem, toPlaylist playlist: Playlist, in context: ModelContext)
    func deleteMediaItem(_ item: MediaItem, in context: ModelContext)
    /// Removes playlist rows whose song was deleted before deletes cascaded.
    func cleanUpOrphanedPlaylistItems(in context: ModelContext)
}
