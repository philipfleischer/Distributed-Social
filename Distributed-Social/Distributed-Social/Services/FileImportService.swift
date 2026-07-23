//
//  FileImportService.swift
//  Distributed-Social
//

import Foundation
import AVFoundation
import SwiftData

enum FileImportError: LocalizedError {
    case noMediaFiles
    case duplicate

    var errorDescription: String? {
        switch self {
        case .noMediaFiles:
            return "No media files were found in the selected folder."
        case .duplicate:
            return "This file is already in your library."
        }
    }
}

final class FileImportService: FileImportServiceProtocol {

    /// Built once at init — avoids repeated URL construction and directory
    /// creation on every import call.
    private let mediaDirectory: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent(Constants.Directories.media)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        mediaDirectory = dir
    }

    func importFile(from sourceURL: URL) async throws -> MediaItem {
        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessed { sourceURL.stopAccessingSecurityScopedResource() } }

        let existingFiles = currentMediaFiles()
        if Self.isDuplicate(sourceURL, in: existingFiles) {
            throw FileImportError.duplicate
        }

        return try await copyAndProcess(sourceURL: sourceURL)
    }

    /// Imports all audio/video files in a folder in parallel. Progress is
    /// reported via `onProgress` as tasks complete (completion order is
    /// non-deterministic; the returned items are re-sorted by name).
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

        // Snapshot the existing library before any parallel write begins so
        // every task uses the same baseline for duplicate detection.
        let existingFiles = currentMediaFiles()

        onProgress(0, fileURLs.count)
        var items: [MediaItem] = []
        var completed = 0

        await withTaskGroup(of: MediaItem?.self) { group in
            for fileURL in fileURLs {
                group.addTask {
                    let inner = fileURL.startAccessingSecurityScopedResource()
                    defer { if inner { fileURL.stopAccessingSecurityScopedResource() } }
                    guard !Self.isDuplicate(fileURL, in: existingFiles) else { return nil }
                    return try? await self.copyAndProcess(sourceURL: fileURL)
                }
            }
            for await result in group {
                completed += 1
                onProgress(completed, fileURLs.count)
                if let item = result { items.append(item) }
            }
        }

        // TaskGroup delivers in completion order — restore filename order.
        items.sort {
            $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
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
            item.artworkData = await displaySizedArtwork(tags.artwork)
        }
        UserDefaults.standard.set(true, forKey: key)
    }

    /// One-time downscale of artwork that older imports stored at full
    /// size — shrinks the database and speeds up first decode. Tracked in
    /// UserDefaults so it only ever runs once.
    func downscaleArtworkIfNeeded(in context: ModelContext) async {
        let key = "artworkDownscaleDone.v1"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        let items = (try? context.fetch(FetchDescriptor<MediaItem>())) ?? []
        for item in items {
            guard let data = item.artworkData else { continue }
            if let scaled = await ArtworkThumbnailCache.downscaledCoverData(from: data),
               scaled.count < data.count {
                item.artworkData = scaled
            }
        }
        UserDefaults.standard.set(true, forKey: key)
    }

    // MARK: - Private helpers

    private func currentMediaFiles() -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: mediaDirectory, includingPropertiesForKeys: [.fileSizeKey])) ?? []
    }

    /// A file with the same original name and byte size as an existing import
    /// is treated as the same song. Every import is stored as
    /// "<UUID>-<originalName>", so the original name is everything after the
    /// 37-char UUID prefix.
    private static func isDuplicate(_ sourceURL: URL, in existingFiles: [URL]) -> Bool {
        guard let sourceSize = try? sourceURL.resourceValues(forKeys: [.fileSizeKey]).fileSize
        else { return false }
        let name = sourceURL.lastPathComponent
        return existingFiles.contains { url in
            url.lastPathComponent.count > 37
                && url.lastPathComponent.dropFirst(37) == name
                && (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) == sourceSize
        }
    }

    /// Copies the file to the media directory, reads embedded tags, and builds
    /// a MediaItem. Duplicate checking is the caller's responsibility.
    private func copyAndProcess(sourceURL: URL) async throws -> MediaItem {
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
            artworkData: await displaySizedArtwork(tags.artwork)
        )
    }

    /// Embedded cover art is often much larger than it ever renders (the
    /// biggest display is the full player at 330 pt ≈ 990 px @3x), so store
    /// a display-sized JPEG instead of the original blob.
    private func displaySizedArtwork(_ data: Data?) async -> Data? {
        guard let data else { return nil }
        guard let scaled = await ArtworkThumbnailCache.downscaledCoverData(from: data),
              scaled.count < data.count else { return data }
        return scaled
    }

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

        return (
            title: (title?.isEmpty == false) ? title : nil,
            artist: (artist?.isEmpty == false) ? artist : nil,
            artwork: artwork
        )
    }
}
