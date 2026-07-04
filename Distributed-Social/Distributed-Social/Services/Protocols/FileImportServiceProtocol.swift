//
//  FileImportServiceProtocol.swift
//  Distributed-Social
//

import Foundation

protocol FileImportServiceProtocol {
    func importFile(from sourceURL: URL) async throws -> MediaItem
    /// Imports every media file inside a folder (sorted by name) and returns
    /// the folder's name plus the imported items, reporting progress along
    /// the way — used by "Import Folder as Playlist".
    func importFolder(from folderURL: URL,
                      onProgress: (_ current: Int, _ total: Int) -> Void) async throws -> (name: String, items: [MediaItem])
    func deleteFile(_ item: MediaItem) throws
}
