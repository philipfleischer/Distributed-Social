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

    private let player = AVPlayer()
    /// Exposed so `VideoPlayerView` can render the current item.
    var avPlayer: AVPlayer { player }

    private var timeObserver: Any?
    private var itemEndObserver: NSObjectProtocol?
    private var resignObserver: NSObjectProtocol?

    private var originalQueue: [MediaItem] = []
    private var activeQueue: [MediaItem] = []
    private var currentIndex: Int = 0

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
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.currentTime = time.seconds.isNaN ? 0 : time.seconds
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
        center.skipForwardCommand.preferredIntervals = [NSNumber(value: Constants.Playback.skipInterval)]
        center.skipForwardCommand.addTarget { [weak self] _ in
            self?.skip(by: Constants.Playback.skipInterval)
            return .success
        }
        center.skipBackwardCommand.preferredIntervals = [NSNumber(value: Constants.Playback.skipInterval)]
        center.skipBackwardCommand.addTarget { [weak self] _ in
            self?.skip(by: -Constants.Playback.skipInterval)
            return .success
        }
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
        info[MPMediaItemPropertyArtist] = "Distributed-Social"
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: - Playback end handling

    private func handlePlaybackEnd() {
        switch repeatMode {
        case .one:
            // Repeat the current song once from the start.
            player.seek(to: .zero)
            player.play()
            player.rate = playbackSpeed
            updateNowPlayingInfo()
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
    }

    func cycleRepeatMode() {
        repeatMode = repeatMode.next()
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
        updateNowPlayingInfo()
    }

    deinit {
        if let obs = timeObserver { player.removeTimeObserver(obs) }
        if let obs = itemEndObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = resignObserver { NotificationCenter.default.removeObserver(obs) }
    }
}
