//
//  ImportViewModel.swift
//  Distributed-Social
//

import Foundation
import Combine

enum ImportState {
    case idle
    case loading
    case success(MediaItem)
    case error(String)
}

@MainActor
final class ImportViewModel: ObservableObject {
    @Published var isPickerPresented: Bool = false
    @Published var state: ImportState = .idle

    private let fileImportService: FileImportServiceProtocol

    init(fileImportService: FileImportServiceProtocol) {
        self.fileImportService = fileImportService
    }

    func presentPicker() { isPickerPresented = true }

    func handlePickedURL(_ url: URL, addToLibrary: (MediaItem) -> Void) async {
        state = .loading
        do {
            let item = try await fileImportService.importFile(from: url)
            addToLibrary(item)
            state = .success(item)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}
