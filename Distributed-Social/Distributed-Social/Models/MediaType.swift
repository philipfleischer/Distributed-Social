//
//  MediaType.swift
//  Distributed-Social
//

import Foundation

enum MediaType: String, Codable, CaseIterable {
    case audio
    case video

    var systemImage: String {
        switch self {
        case .audio: return "music.note"
        case .video: return "film"
        }
    }
}
