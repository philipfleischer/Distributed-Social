//
//  FullPlayerView.swift
//  Distributed-Social
//

import SwiftUI

struct FullPlayerView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if playerVM.currentItem?.mediaType == .video {
                    // Video embed
                    VideoPlayerView(player: playerVM.avPlayer)
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                        .padding(.top, 20)
                } else if let item = playerVM.currentItem {
                    // Unique per-item artwork, matching the library rows.
                    MediaArtworkView(item: item, size: 240)
                        .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
                        .padding(.top, 20)
                }

                // Title
                Text(playerVM.currentItem?.displayName ?? "")
                    .font(.title)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                PlayerControlsView()

                Spacer()
            }
            .summerBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down")
                    }
                }
            }
        }
    }
}
