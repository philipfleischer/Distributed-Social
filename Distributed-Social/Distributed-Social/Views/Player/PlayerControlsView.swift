//
//  PlayerControlsView.swift
//  Distributed-Social
//
//  Shared transport controls used by the full player:
//  progress, shuffle/prev/play/next/repeat, skip ±15, and speed.
//

import SwiftUI

struct PlayerControlsView: View {
    @Environment(PlayerViewModel.self) private var playerVM
    @Environment(ThemeStore.self) private var themeStore

    /// Injected by FullPlayerView so next/prev button taps animate the
    /// carousel.  Falls back to direct service calls when nil (e.g. previews).
    var onNextTrack: (() -> Void)? = nil
    var onPreviousTrack: (() -> Void)? = nil

    private var theme: AppTheme { themeStore.theme }
    private var inactive: Color { Color.gray }

    var body: some View {
        VStack(spacing: 22) {
            PlaybackProgressView()

            HStack(spacing: 32) {
                Button { playerVM.toggleShuffle() } label: {
                    Image(systemName: "shuffle")
                        .font(.title3)
                        .foregroundStyle(playerVM.isShuffleEnabled ? theme.textPrimary : inactive)
                }
                Button {
                    (onPreviousTrack ?? { playerVM.previousTrack() })()
                } label: {
                    Image(systemName: "backward.fill").font(.title)
                }
                Button { playerVM.togglePlayPause() } label: {
                    Image(systemName: playerVM.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(theme.textPrimary)
                }
                .buttonStyle(ScaleOnPressButtonStyle())
                Button {
                    (onNextTrack ?? { playerVM.nextTrack() })()
                } label: {
                    Image(systemName: "forward.fill").font(.title)
                }
                Button { playerVM.cycleRepeatMode() } label: {
                    ZStack {
                        Image(systemName: playerVM.repeatMode.systemImage)
                            .font(.title3)
                            .foregroundStyle(playerVM.repeatMode.isActive ? theme.textPrimary : inactive)
                        if playerVM.repeatMode == .one {
                            Circle()
                                .fill(theme.textPrimary)
                                .frame(width: 5, height: 5)
                                .offset(y: 14)
                        }
                    }
                }
            }
            .foregroundStyle(theme.textPrimary)

            HStack(spacing: 44) {
                Button {
                    Haptics.light()
                    playerVM.skip(by: -Constants.Playback.skipInterval)
                } label: {
                    Image(systemName: "gobackward.15").font(.title2)
                }

                Button {
                    playerVM.currentItem?.isFavorite.toggle()
                    Haptics.light()
                } label: {
                    Image(systemName: (playerVM.currentItem?.isFavorite ?? false) ? "heart.fill" : "heart")
                        .font(.title2)
                        .foregroundStyle((playerVM.currentItem?.isFavorite ?? false) ? Color.red : theme.textPrimary)
                        .frame(minWidth: 56)
                }

                Button {
                    Haptics.light()
                    playerVM.skip(by: Constants.Playback.skipInterval)
                } label: {
                    Image(systemName: "goforward.15").font(.title2)
                }
            }
            .foregroundStyle(theme.textPrimary)
        }
        .padding()
    }
}

/// Scales down slightly on press, springs back on release — applied to the
/// large play/pause button for a snappier tactile feel.
private struct ScaleOnPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

/// The scrubber + time labels. Observes PlaybackTimeModel so the twice-a-
/// second position updates re-render only this small view.
struct PlaybackProgressView: View {
    @Environment(PlayerViewModel.self) private var playerVM
    @Environment(PlaybackTimeModel.self) private var timeModel
    @Environment(ThemeStore.self) private var themeStore
    @State private var isScrubbing = false
    @State private var scrubPosition: TimeInterval = 0

    private var theme: AppTheme { themeStore.theme }

    var body: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { isScrubbing ? scrubPosition : timeModel.currentTime },
                    set: { scrubPosition = $0 }
                ),
                in: 0...(timeModel.duration > 0 ? timeModel.duration : 1)
            ) { editing in
                isScrubbing = editing
                if !editing { playerVM.seek(to: scrubPosition) }
            }
            .tint(theme.textPrimary)
            HStack {
                // Show scrub position during drag so the label tracks the thumb.
                Text(isScrubbing ? scrubPosition.formattedTime : timeModel.currentTime.formattedTime)
                    .font(.subheadline).foregroundStyle(theme.textSecondary)
                Spacer()
                Text(timeModel.duration.formattedTime)
                    .font(.subheadline).foregroundStyle(theme.textSecondary)
            }
        }
        .onChange(of: playerVM.currentItem?.id) { _, _ in
            isScrubbing = false
            scrubPosition = 0
        }
    }
}
