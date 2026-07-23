//
//  VideoLibraryViewModel.swift
//  Distributed-Social
//

import Foundation
import Observation

@Observable
final class VideoLibraryViewModel {
    var searchText: String = ""
    var selectedFolderId: UUID? = nil
    var sortOrder: LibrarySortOrder = .dateImported

    func filteredItems(_ all: [MediaItem]) -> [MediaItem] {
        var items = all
        if let fid = selectedFolderId {
            items = items.filter { $0.folder?.id == fid }
        }
        if !searchText.isEmpty {
            items = items.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
        switch sortOrder {
        case .dateImported:
            break // @Query already sorted newest-first
        case .name:
            items.sort {
                $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
            }
        case .duration:
            items.sort { $0.duration < $1.duration }
        }
        return items
    }
}
