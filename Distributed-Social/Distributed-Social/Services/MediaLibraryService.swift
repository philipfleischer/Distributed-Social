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

    func deletePlaylist(_ playlist: Playlist, in context: ModelContext) {
        for pi in playlist.orderedItems ?? [] { context.delete(pi) }
        context.delete(playlist)
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

    func cleanUpMissingFiles(in context: ModelContext) async {
        let mediaDir = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(Constants.Directories.media)

        // One directory scan off the main thread instead of one fileExists()
        // call per item on the main thread — cuts startup blocking from O(n)
        // file-system calls to a single listing + O(n) set lookups.
        let existingFilenames: Set<String> = await Task.detached(priority: .background) {
            let urls = (try? FileManager.default.contentsOfDirectory(
                at: mediaDir, includingPropertiesForKeys: nil)) ?? []
            return Set(urls.map(\.lastPathComponent))
        }.value

        // Populate fast-path cache so isFileMissing skips per-item disk I/O.
        MediaItem.knownPresentFilenames = existingFilenames

        let all = (try? context.fetch(FetchDescriptor<MediaItem>())) ?? []
        let missing = all.filter { !existingFilenames.contains($0.filename) }
        guard !missing.isEmpty else { return }

        // Collect all affected playlists and delete everything in one pass,
        // then renumber each playlist once instead of once per deleted item.
        var allEntries: [PlaylistItem] = []
        var playlistMap: [ObjectIdentifier: Playlist] = [:]
        for item in missing {
            try? fileImportService.deleteFile(item)
            let entries = item.playlistItems ?? []
            allEntries.append(contentsOf: entries)
            for entry in entries {
                if let pl = entry.playlist { playlistMap[ObjectIdentifier(pl)] = pl }
                context.delete(entry)
            }
            context.delete(item)
        }
        let removedIDs = Set(allEntries.map(\.id))
        for playlist in playlistMap.values {
            renumber(playlist, excluding: removedIDs)
        }
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

    func deleteAudioItemsNotInAnyPlaylist(in context: ModelContext) {
        let audioItems = (try? context.fetch(FetchDescriptor<MediaItem>(
            predicate: #Predicate { $0.mediaTypeRaw == "audio" }
        ))) ?? []
        let allPlaylistItems = (try? context.fetch(FetchDescriptor<PlaylistItem>())) ?? []
        let itemsInPlaylists = Set(allPlaylistItems.compactMap { $0.mediaItem?.id })
        for item in audioItems where !itemsInPlaylists.contains(item.id) {
            deleteMediaItem(item, in: context)
        }
    }

    func addItemToSinglesPlaylist(_ item: MediaItem, in context: ModelContext) {
        let allPlaylists = (try? context.fetch(FetchDescriptor<Playlist>())) ?? []
        let singles: Playlist
        if let existing = allPlaylists.first(where: { $0.name == "Singles" && $0.mediaType == .audio }) {
            singles = existing
        } else {
            singles = Playlist(name: "Singles", mediaType: .audio)
            context.insert(singles)
        }
        let existingIDs = Set((singles.orderedItems ?? []).compactMap { $0.mediaItem?.id })
        guard !existingIDs.contains(item.id) else { return }
        addItem(item, toPlaylist: singles, in: context)
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
