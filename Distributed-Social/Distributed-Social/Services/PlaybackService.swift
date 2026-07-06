//
//  PlaybackService.swift
//  Distributed-Social
//
//  Wraps a single AVPlayer and owns all queue / repeat / shuffle logic.
//  Background audio works because the audio session category is `.playback`
//  and the app declares the `audio` UIBackgroundMode.
//
//  Queue model (Spotify-style):
//  - `manualQueue` is a FIFO of songs the user queued explicitly; it always
//    plays before the context continues.
//  - `contextQueue` is the natural play order (library/playlist the current
//    song came from); after the manual queue drains, playback resumes at
//    the next context position.
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
    /// Songs the user queued manually (FIFO) — play before the context resumes.
    @Published private(set) var queuedItems: [MediaItem] = []
    /// Songs that come next naturally from the current context.
    @Published private(set) var upNext: [MediaItem] = []
    /// When set, playback pauses automatically at this time.
    @Published private(set) var sleepTimerEnd: Date?

    private let player = AVPlayer()
    /// Exposed so `VideoPlayerView` can render the current item.
    var avPlayer: AVPlayer { player }

    private var timeObserver: Any?
    private var itemEndObserver: NSObjectProtocol?
    private var resignObserver: NSObjectProtocol?

    private var originalQueue: [MediaItem] = []   // unshuffled context order
    private var contextQueue: [MediaItem] = []    // active context order
    private var currentIndex: Int = 0             // position in contextQueue
    private var manualQueue: [MediaItem] = []     // user-queued FIFO
    private var isPlayingFromManualQueue = false
    /// Tracks whether `.one` repeat has already replayed the current track,
    /// so each song plays exactly twice before advancing.
    private var hasRepeatedCurrentItem = false
    private var sleepTask: Task<Void, Never>?
    /// Guards the missing-file auto-skip from looping forever when every
    /// remaining song's file is gone.
    private var missingSkipCount = 0

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
        if repeatMode == .one && !hasRepeatedCurrentItem, let item = currentItem {
            // Replay by reloading the item from scratch — the same proven
            // path as any track change. Seeking the *ended* player item and
            // calling play() proved unreliable (the replay never started).
            loadMedia(item, autoPlay: true, startAt: 0)
            hasRepeatedCurrentItem = true // loadMedia resets the flag; set after
            return
        }
        hasRepeatedCurrentItem = false
        advanceAfterEnd()
    }

    /// Picks what plays after the current track ends: the manual queue first,
    /// then the next context item (wrapping only in repeat-all).
    private func advanceAfterEnd() {
        if !manualQueue.isEmpty {
            playNextManualItem(autoPlay: true)
            return
        }
        isPlayingFromManualQueue = false
        let nextIndex = currentIndex + 1
        if nextIndex < contextQueue.count {
            loadItem(at: nextIndex, autoPlay: true)
        } else if repeatMode == .all && !contextQueue.isEmpty {
            loadItem(at: 0, autoPlay: true)
        } else {
            isPlaying = false
            updateNowPlayingInfo()
        }
    }

    // MARK: - Protocol implementation

    func play(item: MediaItem, in queue: [MediaItem], startAt position: TimeInterval = 0) {
        originalQueue = queue
        contextQueue = isShuffleEnabled ? queue.shuffled() : queue

        if let index = contextQueue.firstIndex(where: { $0.id == item.id }) {
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
        // Manually queued songs always play first.
        if !manualQueue.isEmpty {
            playNextManualItem(autoPlay: isPlaying)
            return
        }
        guard !contextQueue.isEmpty else { return }
        isPlayingFromManualQueue = false
        let nextIndex = (currentIndex + 1) % contextQueue.count
        loadItem(at: nextIndex, autoPlay: isPlaying)
    }

    func previousTrack() {
        guard !contextQueue.isEmpty else { return }
        if currentTime > 3 {
            // More than 3s in → restart the current track.
            seek(to: 0)
        } else {
            forcePreviousTrack()
        }
    }

    /// Always moves to the previous song (no restart-current behavior) —
    /// used by the swipe gestures where the card visibly slides to it.
    func forcePreviousTrack() {
        guard !contextQueue.isEmpty else { return }
        if isPlayingFromManualQueue {
            // Back out of the manual detour to the current context song.
            loadItem(at: currentIndex, autoPlay: isPlaying)
        } else {
            let prevIndex = currentIndex == 0 ? contextQueue.count - 1 : currentIndex - 1
            loadItem(at: prevIndex, autoPlay: isPlaying)
        }
    }

    /// The song a "next" action would play right now (manual queue first).
    var peekNext: MediaItem? {
        if let queued = manualQueue.first { return queued }
        guard !contextQueue.isEmpty else { return nil }
        return contextQueue[(currentIndex + 1) % contextQueue.count]
    }

    /// The song a swipe-to-previous would play right now.
    var peekPrevious: MediaItem? {
        guard !contextQueue.isEmpty else { return nil }
        if isPlayingFromManualQueue { return contextQueue[currentIndex] }
        return contextQueue[currentIndex == 0 ? contextQueue.count - 1 : currentIndex - 1]
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
            contextQueue = originalQueue.shuffled()
        } else {
            contextQueue = originalQueue
        }
        if let id = currentItemId,
           let newIndex = contextQueue.firstIndex(where: { $0.id == id }) {
            currentIndex = newIndex
        }
        refreshQueues()
    }

    func cycleRepeatMode() {
        repeatMode = repeatMode.next()
    }

    // MARK: - Sleep timer

    /// Pauses playback after the given number of minutes; nil cancels.
    func setSleepTimer(minutes: Int?) {
        sleepTask?.cancel()
        sleepTask = nil
        guard let minutes else {
            sleepTimerEnd = nil
            return
        }
        let end = Date().addingTimeInterval(TimeInterval(minutes * 60))
        sleepTimerEnd = end
        sleepTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(minutes * 60))
            guard let self, !Task.isCancelled else { return }
            if self.isPlaying { self.togglePlayPause() }
            self.sleepTimerEnd = nil
        }
    }

    func saveCurrentPosition() {
        currentItem?.lastPosition = currentTime
    }

    // MARK: - Queue management

    /// Puts a song at the front of the manual queue.
    func playNext(_ item: MediaItem) {
        guard currentItem != nil else {
            play(item: item, in: [item], startAt: 0)
            return
        }
        manualQueue.insert(item, at: 0)
        refreshQueues()
    }

    /// Appends a song to the end of the manual queue (FIFO).
    func addToQueue(_ item: MediaItem) {
        guard currentItem != nil else {
            play(item: item, in: [item], startAt: 0)
            return
        }
        manualQueue.append(item)
        refreshQueues()
    }

    /// Jumps playback to a song in either queue section. Tapping a manually
    /// queued song drops the entries queued before it (Spotify behavior).
    func jump(to item: MediaItem) {
        if let index = manualQueue.firstIndex(where: { $0.id == item.id }) {
            manualQueue.removeFirst(index)
            playNextManualItem(autoPlay: true)
        } else if let index = contextQueue.firstIndex(where: { $0.id == item.id }) {
            isPlayingFromManualQueue = false
            loadItem(at: index, autoPlay: true)
        }
    }

    func removeFromQueued(at offsets: IndexSet) {
        for offset in offsets.sorted(by: >) where offset < manualQueue.count {
            manualQueue.remove(at: offset)
        }
        refreshQueues()
    }

    func moveQueued(fromOffsets: IndexSet, toOffset: Int) {
        reorder(&manualQueue, fromOffsets: fromOffsets, toOffset: toOffset)
        refreshQueues()
    }

    func removeFromUpNext(at offsets: IndexSet) {
        for offset in offsets.sorted(by: >) {
            let queueIndex = currentIndex + 1 + offset
            guard queueIndex < contextQueue.count else { continue }
            contextQueue.remove(at: queueIndex)
        }
        refreshQueues()
    }

    func moveUpNext(fromOffsets: IndexSet, toOffset: Int) {
        var items = upNext
        reorder(&items, fromOffsets: fromOffsets, toOffset: toOffset)
        contextQueue.replaceSubrange((currentIndex + 1)..., with: items)
        refreshQueues()
    }

    /// Manual reorder (the move(fromOffsets:toOffset:) helper is SwiftUI-only,
    /// which this service intentionally does not import).
    private func reorder(_ items: inout [MediaItem], fromOffsets: IndexSet, toOffset: Int) {
        let moving = fromOffsets.sorted().map { items[$0] }
        let adjustedTarget = toOffset - fromOffsets.count(where: { $0 < toOffset })
        for index in fromOffsets.sorted(by: >) { items.remove(at: index) }
        items.insert(contentsOf: moving, at: min(adjustedTarget, items.count))
    }

    private func refreshQueues() {
        queuedItems = manualQueue
        if currentIndex + 1 < contextQueue.count {
            upNext = Array(contextQueue[(currentIndex + 1)...])
        } else {
            upNext = []
        }
    }

    // MARK: - Private helpers

    /// Loads a context item by index (leaves the manual queue untouched).
    private func loadItem(at index: Int, autoPlay: Bool, startAt position: TimeInterval = 0) {
        guard index < contextQueue.count else { return }
        currentIndex = index
        isPlayingFromManualQueue = false
        loadMedia(contextQueue[index], autoPlay: autoPlay, startAt: position)
    }

    /// Pops and plays the front of the manual queue without moving the
    /// context position, so the context resumes correctly afterwards.
    private func playNextManualItem(autoPlay: Bool) {
        guard !manualQueue.isEmpty else { return }
        let item = manualQueue.removeFirst()
        isPlayingFromManualQueue = true
        loadMedia(item, autoPlay: autoPlay, startAt: 0)
    }

    private func loadMedia(_ item: MediaItem, autoPlay: Bool, startAt position: TimeInterval) {
        // Skip songs whose file has vanished, but never loop the whole
        // queue more than once looking for a playable one.
        if item.isFileMissing {
            missingSkipCount += 1
            if missingSkipCount <= contextQueue.count + queuedItems.count {
                advanceAfterEnd()
            } else {
                missingSkipCount = 0
                isPlaying = false
            }
            return
        }
        missingSkipCount = 0

        currentItem = item
        hasRepeatedCurrentItem = false
        if autoPlay { item.playCount += 1 }

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
        refreshQueues()
        updateNowPlayingInfo()
    }

    deinit {
        if let obs = timeObserver { player.removeTimeObserver(obs) }
        if let obs = itemEndObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = resignObserver { NotificationCenter.default.removeObserver(obs) }
    }
}
