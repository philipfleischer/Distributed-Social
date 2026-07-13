//
//  AudioLibraryViewModel.swift
//  Distributed-Social
//

import Foundation
import Combine

final class AudioLibraryViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var selectedFolderId: UUID? = nil

    func filteredItems(_ all: [MediaItem]) -> [MediaItem] {
        var items = all.filter { $0.mediaType == .audio }
        if let fid = selectedFolderId {
            items = items.filter { $0.folder?.id == fid }
        }
        if !searchText.isEmpty {
            items = items.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
        // The @Query input is already sorted newest-first and filtering
        // preserves order — no re-sort needed.
        return items
    }
}
