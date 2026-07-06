//
//  MediaLibraryService.swift
//  Distributed-Social
//
//  A thin coordinator for cross-cutting SwiftData mutations. Views own their
//  @Query data and pass their environment ModelContext into these methods.
//

import SwiftData
import Foundation
import Combine

final class MediaLibraryService: ObservableObject, MediaLibraryServiceProtocol {

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

    func deleteMediaItem(_ item: MediaItem, fileImportService: FileImportServiceProtocol,
                         in context: ModelContext) {
        try? fileImportService.deleteFile(item)
        context.delete(item)
    }
}
