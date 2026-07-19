//
//  AudioRowView.swift
//  Distributed-Social
//

import SwiftUI

struct AudioRowView<MenuContent: View>: View {
    let item: MediaItem
    let isCurrent: Bool
    let isPlaying: Bool
    var isMissing: Bool = false
    let onPlay: () -> Void
    @ViewBuilder let menuContent: () -> MenuContent

    @EnvironmentObject var themeStore: ThemeStore
    private var theme: AppTheme { themeStore.theme }

    var body: some View {
        HStack(spacing: 14) {
            MediaArtworkView(item: item, size: 56)
                .saturation(isMissing ? 0 : 1)
                .opacity(isMissing ? 0.4 : 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayName)
                    .font(.headline)
                    .foregroundStyle(isMissing ? Color.gray : theme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    if isMissing {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(Color.gray)
                        Text("File no longer available")
                            .font(.subheadline)
                            .foregroundStyle(Color.gray)
                    } else {
                        if isCurrent {
                            Image(systemName: "waveform")
                                .font(.subheadline)
                                .foregroundStyle(theme.textPrimary)
                                .symbolEffect(.variableColor.iterative, isActive: isPlaying)
                        }
                        if let artist = item.artist {
                            Text(artist)
                                .font(.subheadline)
                                .foregroundStyle(theme.textSecondary)
                                .lineLimit(1)
                            Text("·")
                                .foregroundStyle(theme.textSecondary)
                        }
                        Text(item.duration.formattedTime)
                            .font(.subheadline)
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }

            Spacer()

            if !isMissing {
                Button { onPlay() } label: {
                    Image(systemName: isCurrent && isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundStyle(theme.textPrimary)
                }
                .buttonStyle(.plain)

                Menu {
                    menuContent()
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.title3)
                        .foregroundStyle(theme.textSecondary)
                        .rotationEffect(.degrees(90))
                        .frame(width: 32, height: 44)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isMissing { onPlay() }
        }
    }
}
