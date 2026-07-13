//
//  PlaybackTimeModel.swift
//  Distributed-Social
//
//  Exposes only the fast-changing playback clock (position/duration).
//  Kept separate from PlayerViewModel so the 2×-per-second time ticks
//  invalidate ONLY the tiny views that display time (scrubber, mini-player
//  clock) instead of re-rendering every screen observing the player.
//

import Foundation
import Observation

@Observable
final class PlaybackTimeModel {
    private let playbackService: PlaybackService

    var currentTime: TimeInterval { playbackService.currentTime }
    var duration: TimeInterval { playbackService.duration }

    init(playbackService: PlaybackService) {
        self.playbackService = playbackService
    }
}
