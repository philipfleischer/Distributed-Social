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
    @State private var isScrubbing = false
    @State private var scrubPosition: TimeInterval = 0

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
                .tint(.skyBlue)
                HStack {
                    Text(playerVM.currentTime.formattedTime)
                        .font(.subheadline).foregroundStyle(Color.inkSecondary)
                    Spacer()
                    Text(playerVM.duration.formattedTime)
                        .font(.subheadline).foregroundStyle(Color.inkSecondary)
                }
            }

            // Main controls row: shuffle | prev | play/pause | next | repeat
            HStack(spacing: 32) {
                Button { playerVM.toggleShuffle() } label: {
                    Image(systemName: "shuffle")
                        .font(.title3)
                        .foregroundStyle(playerVM.isShuffleEnabled ? Color.skyBlue : Color.inkSecondary)
                }
                Button { playerVM.previousTrack() } label: {
                    Image(systemName: "backward.fill").font(.title)
                }
                Button { playerVM.togglePlayPause() } label: {
                    Image(systemName: playerVM.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(Color.skyBlue)
                }
                Button { playerVM.nextTrack() } label: {
                    Image(systemName: "forward.fill").font(.title)
                }
                // Repeat button — cycles off → all → one → off
                Button { playerVM.cycleRepeatMode() } label: {
                    ZStack {
                        Image(systemName: playerVM.repeatMode.systemImage)
                            .font(.title3)
                            .foregroundStyle(playerVM.repeatMode.isActive ? Color.skyBlue : Color.inkSecondary)
                        if playerVM.repeatMode == .one {
                            Circle()
                                .fill(Color.skyBlue)
                                .frame(width: 5, height: 5)
                                .offset(y: 14)
                        }
                    }
                }
            }
            .foregroundStyle(Color.skyBlue)

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
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                        .overlay(Capsule().strokeBorder(Color.skyBlue.opacity(0.5), lineWidth: 1))
                }

                Button { playerVM.skip(by: Constants.Playback.skipInterval) } label: {
                    Image(systemName: "goforward.15").font(.title2)
                }
            }
            .foregroundStyle(Color.skyBlue)
        }
        .padding()
    }

    private func label(for speed: Float) -> String {
        String(format: "%g×", speed)
    }
}
