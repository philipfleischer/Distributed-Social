//
//  FileImportService.swift
//  Distributed-Social
//

import Foundation
import AVFoundation
import SwiftData

enum FileImportError: LocalizedError {
    case noMediaFiles

    var errorDescription: String? {
        switch self {
        case .noMediaFiles:
            return "No media files were found in the selected folder."
        }
    }
}

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

        // Prefer the file's embedded tags (title / artist / cover art, as
        // written by Spotify and most encoders); fall back to the filename.
        let tags = await loadEmbeddedTags(from: asset)

        let mediaType: MediaType = sourceURL.isVideoFile ? .video : .audio
        let fallbackName = sourceURL.deletingPathExtension().lastPathComponent

        return MediaItem(
            displayName: tags.title ?? fallbackName,
            filename: uniqueFilename,
            mediaType: mediaType,
            duration: duration,
            artist: tags.artist,
            artworkData: tags.artwork
        )
    }

    func importFolder(from folderURL: URL,
                      onProgress: (_ current: Int, _ total: Int) -> Void) async throws -> (name: String, items: [MediaItem]) {
        let accessed = folderURL.startAccessingSecurityScopedResource()
        defer { if accessed { folderURL.stopAccessingSecurityScopedResource() } }

        let fileURLs = try FileManager.default
            .contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
            .filter { $0.isAudioFile || $0.isVideoFile }
            .sorted {
                $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
            }

        guard !fileURLs.isEmpty else { throw FileImportError.noMediaFiles }

        var items: [MediaItem] = []
        for (index, fileURL) in fileURLs.enumerated() {
            onProgress(index + 1, fileURLs.count)
            // Skip unreadable files rather than aborting the whole batch.
            if let item = try? await importFile(from: fileURL) {
                items.append(item)
            }
        }
        return (name: folderURL.lastPathComponent, items: items)
    }

    func deleteFile(_ item: MediaItem) throws {
        guard FileManager.default.fileExists(atPath: item.localURL.path) else { return }
        try FileManager.default.removeItem(at: item.localURL)
    }

    /// One-time backfill: items imported before tag extraction existed get
    /// their embedded title/artist/cover art read now. Tracked in
    /// UserDefaults so it only ever runs once.
    func backfillMetadataIfNeeded(in context: ModelContext) async {
        let key = "metadataBackfillDone.v1"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        let items = (try? context.fetch(FetchDescriptor<MediaItem>())) ?? []
        for item in items where item.artist == nil && item.artworkData == nil {
            guard !item.isFileMissing else { continue }
            let asset = AVURLAsset(url: item.localURL)
            let tags = await loadEmbeddedTags(from: asset)
            if let title = tags.title { item.displayName = title }
            item.artist = tags.artist
            item.artworkData = tags.artwork
        }
        UserDefaults.standard.set(true, forKey: key)
    }

    // MARK: - Embedded metadata

    /// Reads common metadata tags (ID3/iTunes-style) from the asset.
    private func loadEmbeddedTags(from asset: AVURLAsset) async -> (title: String?, artist: String?, artwork: Data?) {
        guard let metadata = try? await asset.load(.commonMetadata) else {
            return (nil, nil, nil)
        }

        let titleItem = AVMetadataItem.metadataItems(
            from: metadata, filteredByIdentifier: .commonIdentifierTitle).first
        let artistItem = AVMetadataItem.metadataItems(
            from: metadata, filteredByIdentifier: .commonIdentifierArtist).first
        let artworkItem = AVMetadataItem.metadataItems(
            from: metadata, filteredByIdentifier: .commonIdentifierArtwork).first

        let title = try? await titleItem?.load(.stringValue)
        let artist = try? await artistItem?.load(.stringValue)
        let artwork = try? await artworkItem?.load(.dataValue)

        // Treat empty strings as missing so fallbacks kick in.
        return (
            title: (title?.isEmpty == false) ? title : nil,
            artist: (artist?.isEmpty == false) ? artist : nil,
            artwork: artwork
        )
    }
}
