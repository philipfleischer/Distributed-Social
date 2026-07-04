//
//  FileImportServiceProtocol.swift
//  Distributed-Social
//

import Foundation

protocol FileImportServiceProtocol {
    func importFile(from sourceURL: URL) async throws -> MediaItem
    func deleteFile(_ item: MediaItem) throws
}
