//
//  AudioRowView.swift
//  Distributed-Social
//

import SwiftUI

struct AudioRowView: View {
    let item: MediaItem
    let onPlay: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "music.note")
                .foregroundStyle(Color.deepSky)
                .frame(width: 40, height: 40)
                .background(Color.skyBlue.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.body)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(item.duration.formattedTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if item.lastPosition > 5 {
                        Text("· \(item.lastPosition.formattedTime) played")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Button { onPlay() } label: {
                Image(systemName: "play.fill")
                    .foregroundStyle(Color.skyBlue)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture { onPlay() }
    }
}
