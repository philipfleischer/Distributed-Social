//
//  MiniPlayerView.swift
//  Distributed-Social
//

import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject var playerVM: PlayerViewModel

    var body: some View {
        HStack(spacing: 16) {
            if let item = playerVM.currentItem {
                MediaArtworkView(item: item, size: 48)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(playerVM.currentItem?.displayName ?? "")
                    .font(.headline)
                    .lineLimit(1)
                Text(playerVM.currentTime.formattedTime + " / " + playerVM.duration.formattedTime)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button { playerVM.previousTrack() } label: {
                Image(systemName: "backward.fill")
                    .font(.title3)
            }
            Button { playerVM.togglePlayPause() } label: {
                Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
            }
            Button { playerVM.nextTrack() } label: {
                Image(systemName: "forward.fill")
                    .font(.title3)
            }
        }
        .foregroundStyle(Color.deepSky)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.sakuraPink.opacity(0.35), lineWidth: 1)
        )
        .padding(.horizontal, 8)
        .shadow(color: Color.skyBlue.opacity(0.25), radius: 6, y: 2)
        .onTapGesture { playerVM.isFullPlayerPresented = true }
    }
}
