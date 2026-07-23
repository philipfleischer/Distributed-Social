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
import MediaPlayer
import Observation
import UIKit

/// A queue slot with its own identity: the same song can sit in a queue
/// twice (e.g. "Add to Queue" tapped twice), so list rows can't be
/// identified by the MediaItem's id without confusing reorder/remove.
struct QueueEntry: Identifiable, Equatable {
    let id = UUID()
    let item: MediaItem

    static func == (lhs: QueueEntry, rhs: QueueEntry) -> Bool { lhs.id == rhs.id }
}

// @Observable (not ObservableObject): views re-render only when a property
// they actually read changes, instead of on every published change — e.g.
// the queue updates on each track change no longer re-render Home.
@Observable
final class PlaybackService: NSObject, PlaybackServiceProtocol {

    private(set) var currentItem: MediaItem?
    private(set) var isPlaying: Bool = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var playbackSpeed: Float = 1.0
    private(set) var isShuffleEnabled: Bool = false
    private(set) var repeatMode: RepeatMode = .off
    /// Songs the user queued manually (FIFO) — play before the context resumes.
    private(set) var queuedItems: [QueueEntry] = []
    /// Songs that come next naturally from the current context.
    private(set) var upNext: [QueueEntry] = []
    /// When set, playback pauses automatically at this time.
    /// Seconds to trim from the end of each song (0 = off).
    private(set) var songFadeSeconds: Int = UserDefaults.standard.integer(forKey: "songFadeSeconds")
    /// Prevents the fade skip from firing more than once per track.
    private var hasFadeSkipped = false

    private let player = AVPlayer()
    /// Exposed so `VideoPlayerView` can render the current item.
    var avPlayer: AVPlayer { player }

    private var timeObserver: Any?
    private var itemEndObserver: NSObjectProtocol?
    private var resignObserver: NSObjectProtocol?
    private var terminateObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?

    private var originalQueue: [QueueEntry] = []  // unshuffled context order
    private var contextQueue: [QueueEntry] = []   // active context order
    private var currentIndex: Int = 0             // position in contextQueue
    private var manualQueue: [QueueEntry] = []    // user-queued FIFO
    private var isPlayingFromManualQueue = false
    /// Entry identity of the playing slot — survives shuffle re-ordering
    /// even when the same song appears twice in the context.
    private var currentEntryID: UUID?
    /// Tracks whether `.one` repeat has already replayed the current track,
    /// so each song plays exactly twice before advancing.
    private var hasRepeatedCurrentItem = false
    /// Guards the missing-file auto-skip from looping forever when every
    /// remaining song's file is gone.
    private var missingSkipCount = 0

    override init() {
        super.init()
        // Everything we play is a local file — skip the streaming-oriented
        // buffering heuristics so tracks start instantly.
        player.automaticallyWaitsToMinimizeStalling = false
        configureAudioSession()
        addTimeObserver()
        addEndObserver()
        addResignObserver()
        addTerminateObserver()
        addInterruptionObserver()
        addRouteChangeObserver()
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
        let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            guard let self else { return }
            // Read the live position instead of the callback's time argument:
            // a queued callback from the previous track could otherwise
            // overwrite the freshly reset position right after a track change,
            // leaving the scrubber stuck at the old spot.
            let seconds = self.player.currentTime().seconds
            self.currentTime = seconds.isNaN ? 0 : seconds

            // Song fade: skip the final N seconds so the user never sits
            // through silence or a long fade-out at the end of a track.
            let fade = self.songFadeSeconds
            if fade > 0, self.duration > 0, !self.hasFadeSkipped {
                if self.currentTime >= self.duration - TimeInterval(fade) {
                    self.hasFadeSkipped = true
                    self.handlePlaybackEnd()
                }
            }
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

    private func addTerminateObserver() {
        terminateObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.saveCurrentPosition()
        }
    }

    /// Phone calls, alarms, Siri: the system pauses the player itself — keep
    /// `isPlaying` in sync so the UI shows the truth, and resume when the
    /// interruption ends (when the system says it's appropriate).
    private func addInterruptionObserver() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            self?.handleInterruption(notification)
        }
    }

    private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        switch type {
        case .began:
            isPlaying = false
            updateNowPlayingInfo()
        case .ended:
            let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            if AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume),
               currentItem != nil {
                player.play()
                player.rate = playbackSpeed
                isPlaying = true
                updateNowPlayingInfo()
            }
        @unknown default:
            break
        }
    }

    /// Headphones unplugged / Bluetooth dropped: the system pauses the
    /// player — sync `isPlaying` so the UI doesn't keep showing "playing".
    private func addRouteChangeObserver() {
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let info = notification.userInfo,
                  let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue),
                  reason == .oldDeviceUnavailable,
                  self.isPlaying else { return }
            self.isPlaying = false
            self.updateNowPlayingInfo()
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
        // Decode the artwork once per track — this method runs on every
        // play/pause/seek/speed change, and re-decoding the full-size image
        // each time was a hidden CPU cost.
        if nowPlayingArtworkItemID != item.id {
            nowPlayingArtworkItemID = item.id
            if let data = item.artworkData, let image = UIImage(data: data) {
                nowPlayingArtwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            } else {
                nowPlayingArtwork = nil
            }
        }
        if let artwork = nowPlayingArtwork {
            info[MPMediaItemPropertyArtwork] = artwork
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// Lock-screen artwork for the current track, built once per track change.
    private var nowPlayingArtwork: MPMediaItemArtwork?
    private var nowPlayingArtworkItemID: UUID?

    // MARK: - Playback end handling

    private func handlePlaybackEnd() {
        // A finished song shouldn't "resume" at its final second next time.
        currentItem?.lastPosition = 0
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
        originalQueue = queue.map { QueueEntry(item: $0) }
        contextQueue = isShuffleEnabled ? originalQueue.shuffled() : originalQueue

        if let index = contextQueue.firstIndex(where: { $0.item.id == item.id }) {
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
        if let queued = manualQueue.first { return queued.item }
        guard !contextQueue.isEmpty else { return nil }
        return contextQueue[(currentIndex + 1) % contextQueue.count].item
    }

    /// The song a swipe-to-previous would play right now.
    var peekPrevious: MediaItem? {
        guard !contextQueue.isEmpty else { return nil }
        if isPlayingFromManualQueue { return contextQueue[currentIndex].item }
        return contextQueue[currentIndex == 0 ? contextQueue.count - 1 : currentIndex - 1].item
    }

    func seek(to position: TimeInterval) {
        // Update immediately so the scrubber reflects the new position
        // right away rather than waiting for the next periodic tick.
        currentTime = position
        let time = CMTime(seconds: position, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: time) { [weak self] _ in
            self?.updateNowPlayingInfo()
        }
    }

    func setSongFade(seconds: Int) {
        songFadeSeconds = seconds
        UserDefaults.standard.set(seconds, forKey: "songFadeSeconds")
    }

    func setSpeed(_ speed: Float) {
        playbackSpeed = speed
        if isPlaying { player.rate = speed }
        updateNowPlayingInfo()
    }

    func toggleShuffle() {
        isShuffleEnabled.toggle()
        contextQueue = isShuffleEnabled ? originalQueue.shuffled() : originalQueue
        if let id = currentEntryID,
           let newIndex = contextQueue.firstIndex(where: { $0.id == id }) {
            currentIndex = newIndex
        }
        refreshQueues()
    }

    func cycleRepeatMode() {
        repeatMode = repeatMode.next()
    }

    func saveCurrentPosition() {
        guard let item = currentItem else { return }
        // Only long content resumes (mixes, audiobooks, podcasts) — regular
        // songs always restart. A listen shorter than a few seconds isn't a
        // resume point either.
        guard item.duration >= Constants.Playback.minDurationToResume,
              currentTime >= Constants.Playback.minPositionToSave else {
            item.lastPosition = 0
            return
        }
        // A track sitting within a second of its end is finished — store 0
        // so it starts over next time instead of resuming at the very end.
        item.lastPosition = currentTime >= max(0, duration - 1) ? 0 : currentTime
    }

    // MARK: - Queue management

    /// Puts a song at the front of the manual queue.
    func playNext(_ item: MediaItem) {
        guard currentItem != nil else {
            play(item: item, in: [item], startAt: 0)
            return
        }
        manualQueue.insert(QueueEntry(item: item), at: 0)
        refreshQueues()
    }

    /// Appends a song to the end of the manual queue (FIFO).
    func addToQueue(_ item: MediaItem) {
        guard currentItem != nil else {
            play(item: item, in: [item], startAt: 0)
            return
        }
        manualQueue.append(QueueEntry(item: item))
        refreshQueues()
    }

    /// Jumps playback to a queue entry in either section. Tapping a manually
    /// queued entry drops the entries queued before it (Spotify behavior).
    func jump(to entry: QueueEntry) {
        if let index = manualQueue.firstIndex(where: { $0.id == entry.id }) {
            manualQueue.removeFirst(index)
            playNextManualItem(autoPlay: true)
        } else if let index = contextQueue.firstIndex(where: { $0.id == entry.id }) {
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

    /// Empties the manual queue (the "In Queue" section of the queue sheet).
    func clearManualQueue() {
        manualQueue.removeAll()
        refreshQueues()
    }

    /// Manual reorder (the move(fromOffsets:toOffset:) helper is SwiftUI-only,
    /// which this service intentionally does not import).
    private func reorder(_ items: inout [QueueEntry], fromOffsets: IndexSet, toOffset: Int) {
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

    /// Detaches an item that is about to be deleted from the library:
    /// purges it from the queues and, if it is the current song, advances
    /// to whatever would play next — or stops and clears playback so no
    /// view keeps referencing the deleted model.
    func removeFromLibrary(_ item: MediaItem) {
        manualQueue.removeAll { $0.item.id == item.id }
        originalQueue.removeAll { $0.item.id == item.id }
        while let index = contextQueue.firstIndex(where: { $0.item.id == item.id }) {
            contextQueue.remove(at: index)
            if index < currentIndex { currentIndex -= 1 }
        }

        if currentItem?.id == item.id {
            if !manualQueue.isEmpty {
                playNextManualItem(autoPlay: isPlaying)
            } else if currentIndex < contextQueue.count {
                // The removal shifted the next song into currentIndex.
                loadItem(at: currentIndex, autoPlay: isPlaying)
            } else {
                clearPlayback()
            }
        }
        refreshQueues()
    }

    /// Stops playback entirely and hides the players (mini player shows
    /// only while currentItem is set).
    private func clearPlayback() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        currentItem = nil
        currentEntryID = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        updateNowPlayingInfo()
    }

    // MARK: - Private helpers

    /// Loads a context item by index (leaves the manual queue untouched).
    private func loadItem(at index: Int, autoPlay: Bool, startAt position: TimeInterval = 0) {
        guard index < contextQueue.count else { return }
        currentIndex = index
        isPlayingFromManualQueue = false
        currentEntryID = contextQueue[index].id
        loadMedia(contextQueue[index].item, autoPlay: autoPlay, startAt: position)
    }

    /// Pops and plays the front of the manual queue without moving the
    /// context position, so the context resumes correctly afterwards.
    private func playNextManualItem(autoPlay: Bool) {
        guard !manualQueue.isEmpty else { return }
        let entry = manualQueue.removeFirst()
        isPlayingFromManualQueue = true
        currentEntryID = entry.id
        loadMedia(entry.item, autoPlay: autoPlay, startAt: 0)
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
        hasFadeSkipped = false

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

        // The duration was probed and stored at import — only parse the
        // asset when the stored value is missing (pre-import-probe items),
        // and write it back so the probe never runs again for this item.
        if item.duration <= 0 {
            Task { [weak self] in
                guard let cmDuration = try? await playerItem.asset.load(.duration),
                      let self, self.currentItem?.id == item.id else { return }
                let seconds = cmDuration.seconds.isNaN ? 0 : cmDuration.seconds
                self.duration = seconds
                item.duration = seconds
                self.updateNowPlayingInfo()
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
        if let obs = terminateObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = interruptionObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = routeChangeObserver { NotificationCenter.default.removeObserver(obs) }
    }
}
