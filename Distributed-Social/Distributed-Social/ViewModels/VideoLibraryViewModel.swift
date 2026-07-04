//
//  VideoLibraryViewModel.swift
//  Distributed-Social
//

import Foundation
import Combine

final class VideoLibraryViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var selectedFolderId: UUID? = nil

    func filteredItems(_ all: [MediaItem]) -> [MediaItem] {
        var items = all.filter { $0.mediaType == .video }
        if let fid = selectedFolderId {
            items = items.filter { $0.folder?.id == fid }
        }
        if !searchText.isEmpty {
            items = items.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
        return items.sorted { $0.dateImported > $1.dateImported }
    }
}
