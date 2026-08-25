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
    func deletePlaylist(_ playlist: Playlist, in context: ModelContext)
    /// Deletes every MediaItem whose backing file no longer exists on disk.
    @MainActor func cleanUpMissingFiles(in context: ModelContext) async
    /// Removes playlist rows whose song was deleted before deletes cascaded.
    func cleanUpOrphanedPlaylistItems(in context: ModelContext)
    /// Deletes audio MediaItems that are not in any playlist (runs on launch).
    func deleteAudioItemsNotInAnyPlaylist(in context: ModelContext)
    /// Finds the "Singles" playlist or creates it, then adds the item if not already present.
    func addItemToSinglesPlaylist(_ item: MediaItem, in context: ModelContext)
}
