//
//  Folder.swift
//  Distributed-Social
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
