//
//  URL+MediaHelpers.swift
//  Distributed-Social
//

import Foundation

extension URL {
    private static let videoExtensions: Set<String> = ["mp4", "mov", "m4v"]
    private static let audioExtensions: Set<String> = ["mp3", "m4a", "wav", "aac", "flac"]

    var isVideoFile: Bool {
        URL.videoExtensions.contains(pathExtension.lowercased())
    }
    var isAudioFile: Bool {
        URL.audioExtensions.contains(pathExtension.lowercased())
    }
}
