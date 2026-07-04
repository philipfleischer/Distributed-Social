//
//  FileImportService.swift
//  Distributed-Social
//

import Foundation
import AVFoundation

final class FileImportService: FileImportServiceProtocol {

    private var mediaDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent(Constants.Directories.media)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func importFile(from sourceURL: URL) async throws -> MediaItem {
        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessed { sourceURL.stopAccessingSecurityScopedResource() } }

        // Unique filename prevents collisions on duplicate names.
        let uniqueFilename = "\(UUID().uuidString)-\(sourceURL.lastPathComponent)"
        let destination = mediaDirectory.appendingPathComponent(uniqueFilename)

        try FileManager.default.copyItem(at: sourceURL, to: destination)

        let asset = AVURLAsset(url: destination)
        let cmDuration = try await asset.load(.duration)
        let duration = cmDuration.seconds.isNaN ? 0 : cmDuration.seconds

        let mediaType: MediaType = sourceURL.isVideoFile ? .video : .audio
        let displayName = sourceURL.deletingPathExtension().lastPathComponent

        return MediaItem(
            displayName: displayName,
            filename: uniqueFilename,
            mediaType: mediaType,
            duration: duration
        )
    }

    func deleteFile(_ item: MediaItem) throws {
        guard FileManager.default.fileExists(atPath: item.localURL.path) else { return }
        try FileManager.default.removeItem(at: item.localURL)
    }
}
