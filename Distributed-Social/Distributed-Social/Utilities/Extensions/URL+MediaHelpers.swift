//
//  URL+MediaHelpers.swift
//  Distributed-Social
//

import Foundation

extension URL {
    var isVideoFile: Bool {
        ["mp4", "mov", "m4v"].contains(pathExtension.lowercased())
    }
    var isAudioFile: Bool {
        ["mp3", "m4a", "wav", "aac", "flac"].contains(pathExtension.lowercased())
    }
}
