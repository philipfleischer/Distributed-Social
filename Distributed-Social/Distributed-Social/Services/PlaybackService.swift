//
//  PlaybackService.swift
//  Distributed-Social
//
//  Wraps a single AVPlayer and owns all queue / repeat / shuffle logic.
//  Background audio works because the audio session category is `.playback`
//  and the app declares the `audio` UIBackgroundMode.
//

import AVFoundation
import Combine
import MediaPlayer
import UIKit

final class PlaybackService: NSObject, ObservableObject, PlaybackServiceProtocol {

    @Published private(set) var currentItem: MediaItem?
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var playbackSpeed: Float = 1.0
    @Published private(set) var isShuffleEnabled: Bool = false
    @Published private(set) var repeatMode: RepeatMode = .off
    /// The songs coming up after the current one, in play order.
    @Published private(set) var upNext: [MediaItem] = []

    private let player = AVPlayer()
    /// Exposed so `VideoPlayerView` can render the current item.
    var avPlayer: AVPlayer { player }

    private var timeObserver: Any?
    private var itemEndObserver: NSObjectProtocol?
    private var resignObserver: NSObjectProtocol?

    private var originalQueue: [MediaItem] = []
    private var activeQueue: [MediaItem] = []
    private var currentIndex: Int = 0
    /// Tracks whether `.one` repeat has already replayed the current track,
    /// so each song plays exactly twice before advancing.
    private var hasRepeatedCurrentItem = false

    override init() {
        super.init()
        configureAudioSession()
        addTimeObserver()
        addEndObserver()
        addResignObserver()
        setupRemoteCommands()
    }

    // MARK: - Setup

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[PlaybackService] AVAudioSession error: \(error)")
        }
    }

    private func addTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            guard let self else { return }
            // Read the live position instead of the callback's time argument:
            // a queued callback from the previous track could otherwise
            // overwrite the freshly reset position right after a track change,
            // leaving the scrubber stuck at the old spot.
            let seconds = self.player.currentTime().seconds
            self.currentTime = seconds.isNaN ? 0 : seconds
        }
    }

    private func addEndObserver() {
        itemEndObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handlePlaybackEnd()
        }
    }

    private func addResignObserver() {
        resignObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.saveCurrentPosition()
        }
    }

    // MARK: - Lock screen / Control Center (Now Playing)

    /// Wires the lock-screen and Control Center transport controls.
    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            guard let self, !self.isPlaying else { return .commandFailed }
            self.togglePlayPause()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            guard let self, self.isPlaying else { return .commandFailed }
            self.togglePlayPause()
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.nextTrack()
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.previousTrack()
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self,
                  let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self.seek(to: positionEvent.positionTime)
            return .success
        }
        // Skip commands stay disabled: when enabled, the lock screen shows
        // ±15s buttons INSTEAD of next/previous track buttons.
        center.skipForwardCommand.isEnabled = false
        center.skipBackwardCommand.isEnabled = false
        center.nextTrackCommand.isEnabled = true
        center.previousTrackCommand.isEnabled = true
    }

    /// Publishes the current track metadata and position to the system so the
    /// lock screen / Dynamic Island player appears and stays in sync.
    private func updateNowPlayingInfo() {
        guard let item = currentItem else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: item.displayName,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? Double(playbackSpeed) : 0.0,
            MPNowPlayingInfoPropertyMediaType: item.mediaType == .audio
                ? MPNowPlayingInfoMediaType.audio.rawValue
                : MPNowPlayingInfoMediaType.video.rawValue
        ]
        info[MPMediaItemPropertyArtist] = item.artist ?? "Distributed-Social"
        if let data = item.artworkData, let image = UIImage(data: data) {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: - Playback end handling

    private func handlePlaybackEnd() {
        switch repeatMode {
        case .one:
            // Replay the current song exactly once, then advance.
            if hasRepeatedCurrentItem {
                hasRepeatedCurrentItem = false
                let nextIndex = currentIndex + 1
                if nextIndex < activeQueue.count {
                    loadItem(at: nextIndex, autoPlay: true)
                } else {
                    isPlaying = false
                    updateNowPlayingInfo()
                }
            } else {
                hasRepeatedCurrentItem = true
                // The player is parked at the end; play() must wait for the
                // seek to finish or it immediately re-fires the end event
                // (which made repeat look like it "did not work").
                player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                    guard let self else { return }
                    self.player.play()
                    self.player.rate = self.playbackSpeed
                    self.updateNowPlayingInfo()
                }
            }
        case .all:
            // Advance; wrap back to the first item at the end.
            let nextIndex = currentIndex + 1
            if nextIndex < activeQueue.count {
                loadItem(at: nextIndex, autoPlay: true)
            } else {
                loadItem(at: 0, autoPlay: true)
            }
        case .off:
            // Advance only if not at the end.
            let nextIndex = currentIndex + 1
            if nextIndex < activeQueue.count {
                loadItem(at: nextIndex, autoPlay: true)
            } else {
                isPlaying = false
                updateNowPlayingInfo()
            }
        }
    }

    // MARK: - Protocol implementation

    func play(item: MediaItem, in queue: [MediaItem], startAt position: TimeInterval = 0) {
        originalQueue = queue
        activeQueue = isShuffleEnabled ? queue.shuffled() : queue

        if let index = activeQueue.firstIndex(where: { $0.id == item.id }) {
            currentIndex = index
        } else {
            currentIndex = 0
        }
        loadItem(at: currentIndex, autoPlay: true, startAt: position)
    }

    func togglePlayPause() {
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            player.rate = playbackSpeed
            isPlaying = true
        }
        updateNowPlayingInfo()
    }

    func skip(by seconds: TimeInterval) {
        let newTime = max(0, min(currentTime + seconds, duration))
        seek(to: newTime)
    }

    func nextTrack() {
        guard !activeQueue.isEmpty else { return }
        let nextIndex = (currentIndex + 1) % activeQueue.count
        loadItem(at: nextIndex, autoPlay: isPlaying)
    }

    func previousTrack() {
        guard !activeQueue.isEmpty else { return }
        if currentTime > 3 {
            // More than 3s in → restart the current track.
            seek(to: 0)
        } else {
            let prevIndex = currentIndex == 0 ? activeQueue.count - 1 : currentIndex - 1
            loadItem(at: prevIndex, autoPlay: isPlaying)
        }
    }

    func seek(to position: TimeInterval) {
        let time = CMTime(seconds: position, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: time) { [weak self] _ in
            self?.updateNowPlayingInfo()
        }
    }

    func setSpeed(_ speed: Float) {
        playbackSpeed = speed
        if isPlaying { player.rate = speed }
        updateNowPlayingInfo()
    }

    func toggleShuffle() {
        isShuffleEnabled.toggle()
        let currentItemId = currentItem?.id
        if isShuffleEnabled {
            activeQueue = originalQueue.shuffled()
        } else {
            activeQueue = originalQueue
        }
        if let id = currentItemId,
           let newIndex = activeQueue.firstIndex(where: { $0.id == id }) {
            currentIndex = newIndex
        }
        refreshUpNext()
    }

    func cycleRepeatMode() {
        repeatMode = repeatMode.next()
    }

    // MARK: - Queue management

    /// Inserts a song directly after the current one.
    func playNext(_ item: MediaItem) {
        guard currentItem != nil else {
            play(item: item, in: [item], startAt: 0)
            return
        }
        activeQueue.insert(item, at: min(currentIndex + 1, activeQueue.count))
        originalQueue.append(item)
        refreshUpNext()
    }

    /// Appends a song to the end of the queue.
    func addToQueue(_ item: MediaItem) {
        guard currentItem != nil else {
            play(item: item, in: [item], startAt: 0)
            return
        }
        activeQueue.append(item)
        originalQueue.append(item)
        refreshUpNext()
    }

    /// Jumps playback to a song already in the queue.
    func jump(to item: MediaItem) {
        guard let index = activeQueue.firstIndex(where: { $0.id == item.id }) else { return }
        loadItem(at: index, autoPlay: true)
    }

    func removeFromUpNext(at offsets: IndexSet) {
        for offset in offsets.sorted(by: >) {
            let queueIndex = currentIndex + 1 + offset
            guard queueIndex < activeQueue.count else { continue }
            activeQueue.remove(at: queueIndex)
        }
        refreshUpNext()
    }

    func moveUpNext(fromOffsets: IndexSet, toOffset: Int) {
        // Manual reorder (the move(fromOffsets:toOffset:) helper is SwiftUI-only,
        // which this service intentionally does not import).
        var items = upNext
        let moving = fromOffsets.sorted().map { items[$0] }
        let adjustedTarget = toOffset - fromOffsets.count(where: { $0 < toOffset })
        for index in fromOffsets.sorted(by: >) { items.remove(at: index) }
        items.insert(contentsOf: moving, at: min(adjustedTarget, items.count))
        activeQueue.replaceSubrange((currentIndex + 1)..., with: items)
        refreshUpNext()
    }

    private func refreshUpNext() {
        if currentIndex + 1 < activeQueue.count {
            upNext = Array(activeQueue[(currentIndex + 1)...])
        } else {
            upNext = []
        }
    }

    func saveCurrentPosition() {
        currentItem?.lastPosition = currentTime
    }

    // MARK: - Private helpers

    private func loadItem(at index: Int, autoPlay: Bool, startAt position: TimeInterval = 0) {
        guard index < activeQueue.count else { return }
        let item = activeQueue[index]
        currentIndex = index
        currentItem = item
        hasRepeatedCurrentItem = false

        // Reset published time state immediately so the scrubber snaps to the
        // start of the new track instead of holding the previous position
        // until the next periodic tick.
        currentTime = position
        duration = item.duration

        let playerItem = AVPlayerItem(url: item.localURL)
        player.replaceCurrentItem(with: playerItem)

        if position > 0 {
            let time = CMTime(seconds: position, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            player.seek(to: time)
        }

        // Load the real duration asynchronously.
        Task { [weak self] in
            if let cmDuration = try? await playerItem.asset.load(.duration) {
                await MainActor.run {
                    self?.duration = cmDuration.seconds.isNaN ? 0 : cmDuration.seconds
                    self?.updateNowPlayingInfo()
                }
            }
        }

        if autoPlay {
            player.play()
            player.rate = playbackSpeed
            isPlaying = true
        }
        refreshUpNext()
        updateNowPlayingInfo()
    }

    deinit {
        if let obs = timeObserver { player.removeTimeObserver(obs) }
        if let obs = itemEndObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = resignObserver { NotificationCenter.default.removeObserver(obs) }
    }
}
