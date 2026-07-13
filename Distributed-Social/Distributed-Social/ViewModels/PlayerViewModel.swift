//
//  PlayerViewModel.swift
//  Distributed-Social
//
//  Bridges PlaybackService state to all player UI. @Observable tracking is
//  per-property: a view re-renders only when a property it actually read
//  changes, so e.g. queue updates no longer re-render Home or the libraries.
//

import AVFoundation
import Foundation
import Observation

@Observable
final class PlayerViewModel {
    // NOTE: currentTime/duration deliberately live in PlaybackTimeModel —
    // keeping the twice-a-second clock out of this type makes it impossible
    // for a screen to re-render on time ticks by accident.
    var isFullPlayerPresented: Bool = false
    /// The playlist currently being played, if playback started from one —
    /// used to highlight it in the Playlists grid and Home carousels.
    var currentPlaylistID: UUID? = nil
    /// Transient confirmation message (e.g. "added to queue").
    private(set) var toast: String? = nil

    @ObservationIgnored private var toastTask: Task<Void, Never>?
    private let playbackService: PlaybackService

    // Service state, forwarded — observation tracks straight through these
    // computed properties into the @Observable PlaybackService.
    var isPlaying: Bool { playbackService.isPlaying }
    var currentItem: MediaItem? { playbackService.currentItem }
    var playbackSpeed: Float { playbackService.playbackSpeed }
    var isShuffleEnabled: Bool { playbackService.isShuffleEnabled }
    var repeatMode: RepeatMode { playbackService.repeatMode }
    /// Manually queued songs (FIFO) — play before the context resumes.
    var queuedItems: [MediaItem] { playbackService.queuedItems }
    /// Songs that come next naturally from the current context.
    var upNext: [MediaItem] { playbackService.upNext }
    /// When set, playback pauses automatically at this time.
    var sleepTimerEnd: Date? { playbackService.sleepTimerEnd }

    /// What a next / previous swipe would play — drives the slide-in previews.
    var nextItem: MediaItem? { playbackService.peekNext }
    var previousItem: MediaItem? { playbackService.peekPrevious }

    /// Exposed so the video player view can attach to the active AVPlayer.
    var avPlayer: AVPlayer { playbackService.avPlayer }

    init(playbackService: PlaybackService) {
        self.playbackService = playbackService
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
