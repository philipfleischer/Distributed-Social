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
        VStack(spacing: 20) {
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
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(playerVM.duration.formattedTime)
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            // Main controls row: shuffle | prev | play/pause | next | repeat
            HStack(spacing: 32) {
                Button { playerVM.toggleShuffle() } label: {
                    Image(systemName: "shuffle")
                        .foregroundStyle(playerVM.isShuffleEnabled ? Color.skyBlue : Color.primary)
                }
                Button { playerVM.previousTrack() } label: {
                    Image(systemName: "backward.fill").font(.title2)
                }
                Button { playerVM.togglePlayPause() } label: {
                    Image(systemName: playerVM.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Color.skyBlue)
                }
                Button { playerVM.nextTrack() } label: {
                    Image(systemName: "forward.fill").font(.title2)
                }
                // Repeat button — cycles off → all → one → off
                Button { playerVM.cycleRepeatMode() } label: {
                    ZStack {
                        Image(systemName: playerVM.repeatMode.systemImage)
                            .foregroundStyle(playerVM.repeatMode.isActive ? Color.skyBlue : Color.primary)
                        if playerVM.repeatMode == .one {
                            Circle()
                                .fill(Color.skyBlue)
                                .frame(width: 5, height: 5)
                                .offset(y: 12)
                        }
                    }
                }
            }
            .foregroundStyle(Color.primary)

            // Skip buttons row
            HStack(spacing: 48) {
                Button { playerVM.skip(by: -Constants.Playback.skipInterval) } label: {
                    Image(systemName: "gobackward.15").font(.title3)
                }
                Button { playerVM.skip(by: Constants.Playback.skipInterval) } label: {
                    Image(systemName: "goforward.15").font(.title3)
                }
            }
            .foregroundStyle(Color.deepSky)

            // Speed picker
            Picker("Speed", selection: Binding(
                get: { playerVM.playbackSpeed },
                set: { playerVM.setSpeed($0) }
            )) {
                Text("0.75×").tag(Float(0.75))
                Text("1×").tag(Float(1.0))
                Text("1.25×").tag(Float(1.25))
                Text("1.5×").tag(Float(1.5))
                Text("2×").tag(Float(2.0))
            }
            .pickerStyle(.segmented)
        }
        .padding()
    }
}
