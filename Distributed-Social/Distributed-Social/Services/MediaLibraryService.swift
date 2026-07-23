//
//  MediaLibraryService.swift
//  Distributed-Social
//
//  A thin coordinator for cross-cutting SwiftData mutations. Views own their
//  @Query data and pass their environment ModelContext into these methods.
//

import SwiftData
import Foundation
import Observation

@Observable
final class MediaLibraryService: MediaLibraryServiceProtocol {

    private let fileImportService: FileImportServiceProtocol

    init(fileImportService: FileImportServiceProtocol) {
        self.fileImportService = fileImportService
    }

    @discardableResult
    func createPlaylist(name: String, mediaType: MediaType,
                        in context: ModelContext) -> Playlist {
        let playlist = Playlist(name: name, mediaType: mediaType)
        context.insert(playlist)
        return playlist
    }

    func addItem(_ item: MediaItem, toPlaylist playlist: Playlist,
                 in context: ModelContext) {
        let nextOrder = (playlist.orderedItems?.count ?? 0)
        let pi = PlaylistItem(mediaItem: item, playlist: playlist, sortOrder: nextOrder)
        context.insert(pi)
    }

    func deleteMediaItem(_ item: MediaItem, in context: ModelContext) {
        try? fileImportService.deleteFile(item)
        // Deleting a song must also delete its playlist rows — the default
        // nullify rule would leave invisible orphans that skew the tile
        // counts and skip track numbers.
        let entries = item.playlistItems ?? []
        let affectedPlaylists = Set(entries.compactMap(\.playlist))
        let removedIDs = Set(entries.map(\.id))
        for entry in entries { context.delete(entry) }
        for playlist in affectedPlaylists {
            renumber(playlist, excluding: removedIDs)
        }
        context.delete(item)
    }

    /// Removes playlist rows orphaned by deletes that predate the cascade
    /// in `deleteMediaItem` (their song is gone, so `mediaItem` is nil).
    /// Cheap enough to run on every launch as a self-healing pass.
    func cleanUpOrphanedPlaylistItems(in context: ModelContext) {
        let all = (try? context.fetch(FetchDescriptor<PlaylistItem>())) ?? []
        let orphans = all.filter { $0.mediaItem == nil }
        guard !orphans.isEmpty else { return }
        let affectedPlaylists = Set(orphans.compactMap(\.playlist))
        let removedIDs = Set(orphans.map(\.id))
        for orphan in orphans { context.delete(orphan) }
        for playlist in affectedPlaylists {
            renumber(playlist, excluding: removedIDs)
        }
    }

    /// Reassigns contiguous sort orders, skipping rows that are being
    /// deleted (they may still appear in the relationship until the save).
    private func renumber(_ playlist: Playlist, excluding removedIDs: Set<UUID>) {
        let remaining = playlist.sortedItems.filter { !removedIDs.contains($0.id) }
        for (index, entry) in remaining.enumerated() {
            entry.sortOrder = index
        }
    }
}
