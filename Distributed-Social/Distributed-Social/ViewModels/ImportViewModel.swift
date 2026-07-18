//
//  ImportViewModel.swift
//  Distributed-Social
//

import Foundation
import Combine

enum ImportState: Equatable {
    case idle
    case importing(current: Int, total: Int)
    case success(String)
    case error(String)
}

@MainActor
final class ImportViewModel: ObservableObject {
    @Published var isPickerPresented: Bool = false
    @Published var isFolderPickerPresented: Bool = false
    @Published var state: ImportState = .idle

    private let fileImportService: FileImportServiceProtocol

    init(fileImportService: FileImportServiceProtocol) {
        self.fileImportService = fileImportService
    }

    func presentPicker() { isPickerPresented = true }
    func presentFolderPicker() { isFolderPickerPresented = true }

    /// Imports one or more individually picked files.
    func handlePickedFiles(_ urls: [URL], addToLibrary: (MediaItem) -> Void) async {
        guard !urls.isEmpty else { return }
        var imported = 0
        var duplicates = 0
        for (index, url) in urls.enumerated() {
            state = .importing(current: index + 1, total: urls.count)
            do {
                let item = try await fileImportService.importFile(from: url)
                addToLibrary(item)
                imported += 1
            } catch FileImportError.duplicate {
                duplicates += 1
            } catch {
                // Keep going; report the overall result at the end.
            }
        }
        if imported > 0 {
            var message = "Imported \(imported) file\(imported == 1 ? "" : "s")"
            if duplicates > 0 {
                message += " · skipped \(duplicates) duplicate\(duplicates == 1 ? "" : "s")"
            }
            flash(.success(message))
        } else if duplicates > 0 {
            flash(.success("Already in your library — skipped \(duplicates) duplicate\(duplicates == 1 ? "" : "s")"))
        } else {
            flash(.error("None of the selected files could be imported."))
        }
    }

    /// Imports a whole folder and hands the result to the caller, which
    /// creates the playlist (needs the view's ModelContext).
    func handlePickedFolder(_ url: URL,
                            createPlaylist: (_ name: String, _ items: [MediaItem]) -> Void) async {
        state = .importing(current: 0, total: 0)
        do {
            let result = try await fileImportService.importFolder(from: url) { [weak self] current, total in
                self?.state = .importing(current: current, total: total)
            }
            // Every file was a duplicate (folder re-imported) — creating an
            // empty playlist would only confuse.
            guard !result.items.isEmpty else {
                flash(.success("All songs in “\(result.name)” are already in your library"))
                return
            }
            createPlaylist(result.name, result.items)
            flash(.success("Created playlist “\(result.name)” with \(result.items.count) song\(result.items.count == 1 ? "" : "s")"))
        } catch {
            flash(.error(error.localizedDescription))
        }
    }

    /// Shows a result state as a transient toast, then returns to idle.
    private func flash(_ result: ImportState) {
        state = result
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            if self?.state == result {
                self?.state = .idle
            }
        }
    }
}
