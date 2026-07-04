//
//  PlaybackServiceProtocol.swift
//  Distributed-Social
//

import Foundation

enum RepeatMode: String, CaseIterable {
    case off          // no repeat
    case all          // loop entire playlist: last song → first song
    case one          // repeat current song before advancing

    var systemImage: String {
        switch self {
        case .off: return "repeat"
        case .all: return "repeat"
        case .one: return "repeat.1"
        }
    }

    var isActive: Bool { self != .off }

    func next() -> RepeatMode {
        switch self {
        case .off: return .all
        case .all: return .one
        case .one: return .off
        }
    }
}

protocol PlaybackServiceProtocol: AnyObject {
    var currentItem: MediaItem? { get }
    var isPlaying: Bool { get }
    var currentTime: TimeInterval { get }
    var duration: TimeInterval { get }
    var playbackSpeed: Float { get }
    var isShuffleEnabled: Bool { get }
    var repeatMode: RepeatMode { get }

    func play(item: MediaItem, in queue: [MediaItem], startAt position: TimeInterval)
    func togglePlayPause()
    func skip(by seconds: TimeInterval)
    func nextTrack()
    func previousTrack()
    func seek(to position: TimeInterval)
    func setSpeed(_ speed: Float)
    func toggleShuffle()
    func cycleRepeatMode()
    func saveCurrentPosition()
}
