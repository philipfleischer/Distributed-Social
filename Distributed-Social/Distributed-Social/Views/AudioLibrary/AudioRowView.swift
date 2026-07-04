//
//  AudioRowView.swift
//  Distributed-Social
//

import SwiftUI

struct AudioRowView<MenuContent: View>: View {
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
                    .foregroundStyle(isCurrent ? Color.deepSky : Color.primary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    if isCurrent {
                        Image(systemName: "waveform")
                            .font(.subheadline)
                            .foregroundStyle(Color.deepSky)
                            .symbolEffect(.variableColor.iterative, isActive: isPlaying)
                    }
                    Text(item.duration.formattedTime)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if item.lastPosition > 5 {
                        Text("· \(item.lastPosition.formattedTime) played")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Button { onPlay() } label: {
                Image(systemName: isCurrent && isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .foregroundStyle(Color.deepSky)
            }
            .buttonStyle(.plain)

            Menu {
                menuContent()
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3)
                    .foregroundStyle(.secondary)
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
