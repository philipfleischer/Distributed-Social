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
    /// Manually queued songs (FIFO) — play before the context resumes.
    @Published var queuedItems: [MediaItem] = []
    /// Songs that come next naturally from the current context.
    @Published var upNext: [MediaItem] = []
    /// Transient confirmation message (e.g. "added to queue").
    @Published var toast: String? = nil
    /// When set, playback pauses automatically at this time.
    @Published var sleepTimerEnd: Date? = nil

    private var toastTask: Task<Void, Never>?

    /// What a next / previous swipe would play — drives the slide-in previews.
    var nextItem: MediaItem? { playbackService.peekNext }
    var previousItem: MediaItem? { playbackService.peekPrevious }

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
        playbackService.$queuedItems.assign(to: &$queuedItems)
        playbackService.$sleepTimerEnd.assign(to: &$sleepTimerEnd)
    }

    func togglePlayPause() { playbackService.togglePlayPause() }
    func skip(by s: TimeInterval) { playbackService.skip(by: s) }
    func nextTrack() { playbackService.nextTrack() }
    func previousTrack() { playbackService.previousTrack() }
    func seek(to t: TimeInterval) { playbackService.seek(to: t) }
    func setSpeed(_ s: Float) { playbackService.setSpeed(s) }
    func toggleShuffle() { playbackService.toggleShuffle() }
    func cycleRepeatMode() { playbackService.cycleRepeatMode() }
    func playNext(_ item: MediaItem) {
        playbackService.playNext(item)
        showToast("“\(item.displayName)” will play next")
    }
    func addToQueue(_ item: MediaItem) {
        playbackService.addToQueue(item)
        showToast("“\(item.displayName)” added to queue")
    }
    /// Swipe variant of previous: always goes to the previous song.
    func swipeToPreviousTrack() { playbackService.forcePreviousTrack() }
    /// Pauses playback after the given number of minutes; nil turns it off.
    func setSleepTimer(minutes: Int?) { playbackService.setSleepTimer(minutes: minutes) }

    private func showToast(_ message: String) {
        Haptics.success()
        toast = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            if !Task.isCancelled { self?.toast = nil }
        }
    }
    func jump(to item: MediaItem) { playbackService.jump(to: item) }
    func removeFromUpNext(at offsets: IndexSet) { playbackService.removeFromUpNext(at: offsets) }
    func moveUpNext(fromOffsets: IndexSet, toOffset: Int) {
        playbackService.moveUpNext(fromOffsets: fromOffsets, toOffset: toOffset)
    }
    func removeFromQueued(at offsets: IndexSet) { playbackService.removeFromQueued(at: offsets) }
    func moveQueued(fromOffsets: IndexSet, toOffset: Int) {
        playbackService.moveQueued(fromOffsets: fromOffsets, toOffset: toOffset)
    }

    func play(item: MediaItem, in queue: [MediaItem]) {
        playbackService.play(item: item, in: queue, startAt: item.lastPosition)
        isFullPlayerPresented = true
    }
}
