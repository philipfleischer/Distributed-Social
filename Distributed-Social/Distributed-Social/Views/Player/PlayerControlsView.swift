//
//  PlayerControlsView.swift
//  Distributed-Social
//
//  Shared transport controls used by the full player:
//  progress, shuffle/prev/play/next/repeat, skip ±15, and speed.
//

import SwiftUI

struct PlayerControlsView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var themeStore: ThemeStore
    @State private var isScrubbing = false
    @State private var scrubPosition: TimeInterval = 0

    private var theme: AppTheme { themeStore.theme }
    /// Inactive toggle buttons use plain grey so the active accent color is
    /// unmistakable.
    private var inactive: Color { Color.gray }

    var body: some View {
        VStack(spacing: 22) {
            // Progress bar
            VStack(spacing: 4) {
                Slider(
                    value: Binding(
                        get: { isScrubbing ? scrubPosition : playerVM.currentTime },
                        set: { scrubPosition = $0 }
                    ),
                    in: 0...(playerVM.duration > 0 ? playerVM.duration : 1)
                ) { editing in
                    isScrubbing = editing
                    if !editing { playerVM.seek(to: scrubPosition) }
                }
                .tint(theme.textPrimary)
                HStack {
                    Text(playerVM.currentTime.formattedTime)
                        .font(.subheadline).foregroundStyle(theme.textSecondary)
                    Spacer()
                    Text(playerVM.duration.formattedTime)
                        .font(.subheadline).foregroundStyle(theme.textSecondary)
                }
            }

            // Main controls row: shuffle | prev | play/pause | next | repeat
            HStack(spacing: 32) {
                Button { playerVM.toggleShuffle() } label: {
                    Image(systemName: "shuffle")
                        .font(.title3)
                        .foregroundStyle(playerVM.isShuffleEnabled ? theme.textPrimary : inactive)
                }
                Button { playerVM.previousTrack() } label: {
                    Image(systemName: "backward.fill").font(.title)
                }
                Button { playerVM.togglePlayPause() } label: {
                    Image(systemName: playerVM.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(theme.textPrimary)
                }
                Button { playerVM.nextTrack() } label: {
                    Image(systemName: "forward.fill").font(.title)
                }
                // Repeat button — cycles off → all → one → off
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

            // Skip buttons + speed menu row
            HStack(spacing: 44) {
                Button { playerVM.skip(by: -Constants.Playback.skipInterval) } label: {
                    Image(systemName: "gobackward.15").font(.title2)
                }

                // Speed: shows current value; tap to pick from a menu.
                Menu {
                    ForEach(Constants.Playback.speeds, id: \.self) { speed in
                        Button {
                            playerVM.setSpeed(speed)
                        } label: {
                            if playerVM.playbackSpeed == speed {
                                Label(label(for: speed), systemImage: "checkmark")
                            } else {
                                Text(label(for: speed))
                            }
                        }
                    }
                } label: {
                    Text(label(for: playerVM.playbackSpeed))
                        .font(.headline)
                        .frame(minWidth: 56)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(Capsule().fill(theme.chipFill))
                        .overlay(Capsule().strokeBorder(theme.textPrimary.opacity(0.5), lineWidth: 1))
                }

                Button { playerVM.skip(by: Constants.Playback.skipInterval) } label: {
                    Image(systemName: "goforward.15").font(.title2)
                }
            }
            .foregroundStyle(theme.textPrimary)
        }
        .padding()
        .onChange(of: playerVM.currentItem?.id) { _, _ in
            // New track: drop any in-flight scrub state so the thumb snaps
            // back to the start immediately.
            isScrubbing = false
            scrubPosition = 0
        }
    }

    private func label(for speed: Float) -> String {
        String(format: "%g×", speed)
    }
}
