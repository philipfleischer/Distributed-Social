//
//  Folder.swift
//  Distributed-Social
//
//  NOTE: The folders feature was removed from the UI. The model (and the
//  MediaItem.folder relationship) stays in the schema so existing on-device
//  stores keep migrating cleanly.
//

import SwiftData
import Foundation

@Model
final class Folder {
    var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = "#7CC5E8"
    @Relationship(inverse: \MediaItem.folder) var items: [MediaItem]?

    init(name: String, colorHex: String = "#7CC5E8") {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
    }
}
