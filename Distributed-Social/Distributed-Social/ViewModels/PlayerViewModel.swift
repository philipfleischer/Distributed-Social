//
//  PlayerViewModel.swift
//  Distributed-Social
//
//  Bridges PlaybackService state to all player UI via Combine bindings.
//

import AVFoundation
import Combine
import Foundation

final class PlayerViewModel: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentItem: MediaItem? = nil
    @Published var playbackSpeed: Float = 1.0
    @Published var isShuffleEnabled: Bool = false
    @Published var repeatMode: RepeatMode = .off
    @Published var isFullPlayerPresented: Bool = false
    /// The playlist currently being played, if playback started from one —
    /// used to highlight it in the Playlists grid and Home carousels.
    @Published var currentPlaylistID: UUID? = nil
    /// Songs coming up after the current one (queue view).
    @Published var upNext: [MediaItem] = []

    private let playbackService: PlaybackService

    /// Exposed so the video player view can attach to the active AVPlayer.
    var avPlayer: AVPlayer { playbackService.avPlayer }

    init(playbackService: PlaybackService) {
        self.playbackService = playbackService
        bindToService()
    }

    private func bindToService() {
        playbackService.$isPlaying.assign(to: &$isPlaying)
        playbackService.$currentTime.assign(to: &$currentTime)
        playbackService.$duration.assign(to: &$duration)
        playbackService.$currentItem.assign(to: &$currentItem)
        playbackService.$playbackSpeed.assign(to: &$playbackSpeed)
        playbackService.$isShuffleEnabled.assign(to: &$isShuffleEnabled)
        playbackService.$repeatMode.assign(to: &$repeatMode)
        playbackService.$upNext.assign(to: &$upNext)
    }

    func togglePlayPause() { playbackService.togglePlayPause() }
    func skip(by s: TimeInterval) { playbackService.skip(by: s) }
    func nextTrack() { playbackService.nextTrack() }
    func previousTrack() { playbackService.previousTrack() }
    func seek(to t: TimeInterval) { playbackService.seek(to: t) }
    func setSpeed(_ s: Float) { playbackService.setSpeed(s) }
    func toggleShuffle() { playbackService.toggleShuffle() }
    func cycleRepeatMode() { playbackService.cycleRepeatMode() }
    func playNext(_ item: MediaItem) { playbackService.playNext(item) }
    func addToQueue(_ item: MediaItem) { playbackService.addToQueue(item) }
    func jump(to item: MediaItem) { playbackService.jump(to: item) }
    func removeFromUpNext(at offsets: IndexSet) { playbackService.removeFromUpNext(at: offsets) }
    func moveUpNext(fromOffsets: IndexSet, toOffset: Int) {
        playbackService.moveUpNext(fromOffsets: fromOffsets, toOffset: toOffset)
    }

    func play(item: MediaItem, in queue: [MediaItem]) {
        playbackService.play(item: item, in: queue, startAt: item.lastPosition)
        isFullPlayerPresented = true
    }
}
