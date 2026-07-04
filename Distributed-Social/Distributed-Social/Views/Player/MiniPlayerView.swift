//
//  MiniPlayerView.swift
//  Distributed-Social
//

import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject var playerVM: PlayerViewModel

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: playerVM.currentItem?.mediaType.systemImage ?? "music.note")
                .font(.title2)
                .foregroundStyle(Color.deepSky)
                .frame(width: 44, height: 44)
                .background(Color.skyBlue.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(playerVM.currentItem?.displayName ?? "")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(playerVM.currentTime.formattedTime + " / " + playerVM.duration.formattedTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button { playerVM.previousTrack() } label: {
                Image(systemName: "backward.fill")
            }
            Button { playerVM.togglePlayPause() } label: {
                Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
            }
            Button { playerVM.nextTrack() } label: {
                Image(systemName: "forward.fill")
            }
        }
        .foregroundStyle(Color.deepSky)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.sakuraPink.opacity(0.35), lineWidth: 1)
        )
        .padding(.horizontal, 8)
        .shadow(color: Color.skyBlue.opacity(0.25), radius: 6, y: 2)
        .onTapGesture { playerVM.isFullPlayerPresented = true }
    }
}
