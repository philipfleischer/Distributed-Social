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
                } else {
                    // Artwork / icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [Color.sakuraPink.opacity(0.35), Color.skyBlue.opacity(0.35)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 240, height: 240)
                        Image(systemName: playerVM.currentItem?.mediaType.systemImage ?? "music.note")
                            .font(.system(size: 80))
                            .foregroundStyle(Color.deepSky)
                    }
                    .padding(.top, 20)
                }

                // Title
                Text(playerVM.currentItem?.displayName ?? "")
                    .font(.title2)
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
