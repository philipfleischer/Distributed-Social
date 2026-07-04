//
//  VideoRowView.swift
//  Distributed-Social
//

import SwiftUI

struct VideoRowView<MenuContent: View>: View {
    let item: MediaItem
    let isCurrent: Bool
    let isPlaying: Bool
    let onPlay: () -> Void
    @ViewBuilder let menuContent: () -> MenuContent

    var body: some View {
        HStack(spacing: 14) {
            MediaArtworkView(item: item, size: 56)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayName)
                    .font(.headline)
                    .foregroundStyle(Color.skyBlue)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    if isCurrent {
                        Image(systemName: "waveform")
                            .font(.subheadline)
                            .foregroundStyle(Color.deepSky)
                            .symbolEffect(.variableColor.iterative, isActive: isPlaying)
                    }
                    if let artist = item.artist {
                        Text(artist)
                            .font(.subheadline)
                            .foregroundStyle(Color.inkSecondary)
                            .lineLimit(1)
                        Text("·")
                            .foregroundStyle(Color.inkSecondary)
                    }
                    Text(item.duration.formattedTime)
                        .font(.subheadline)
                        .foregroundStyle(Color.inkSecondary)
                }
            }

            Spacer()

            Button { onPlay() } label: {
                Image(systemName: isCurrent && isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .foregroundStyle(Color.skyBlue)
            }
            .buttonStyle(.plain)

            Menu {
                menuContent()
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3)
                    .foregroundStyle(Color.inkSecondary)
                    .rotationEffect(.degrees(90))
                    .frame(width: 32, height: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { onPlay() }
    }
}
