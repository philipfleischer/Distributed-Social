//
//  CombinedPlaylistView.swift
//  Distributed-Social
//
//  Temporary in-session playlist assembled from user-selected playlists.
//  Not persisted — disappears when the app restarts.
//

import SwiftUI

struct CombinedPlaylistView: View {
    let items: [MediaItem]

    @Environment(PlayerViewModel.self) private var playerVM
    @Environment(ThemeStore.self) private var themeStore
    private var theme: AppTheme { themeStore.theme }

    private var playableItems: [MediaItem] { items.filter { !$0.isFileMissing } }

    var body: some View {
        Group {
            if items.isEmpty {
                ContentUnavailableView(
                    "No Songs",
                    systemImage: "list.bullet",
                    description: Text("The selected playlists have no songs.")
                )
            } else {
                List(items) { item in
                    let isCurrent = playerVM.currentItem?.id == item.id
                    let isMissing = item.isFileMissing
                    HStack(spacing: 10) {
                        MediaArtworkView(item: item, size: 44)
                            .saturation(isMissing ? 0 : 1)
                            .opacity(isMissing ? 0.4 : 1)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.displayName)
                                .font(.body.weight(isCurrent ? .semibold : .regular))
                                .foregroundStyle(isMissing ? .gray : (isCurrent ? theme.textHighlight : theme.textPrimary))
                                .lineLimit(1)
                            if let artist = item.artist {
                                Text(artist)
                                    .font(.caption)
                                    .foregroundStyle(theme.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        if isCurrent && !isMissing {
                            Image(systemName: "waveform")
                                .foregroundStyle(theme.textPrimary)
                                .symbolEffect(.variableColor.iterative, isActive: playerVM.isPlaying)
                        }
                        Spacer()
                        Text(item.duration.formattedTime)
                            .font(.caption)
                            .foregroundStyle(isMissing ? Color.gray : theme.textSecondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard !isMissing else { return }
                        playerVM.currentPlaylistID = nil
                        playerVM.play(item: item, in: playableItems)
                    }
                    .swipeToQueue(enabled: !isMissing) {
                        playerVM.addToQueue(item)
                    }
                    .listRowBackground(Color.clear)
                }
                .scrollContentBackground(.hidden)
                .contentMargins(.bottom, 120, for: .scrollContent)
            }
        }
        .summerBackground()
        .navigationTitle("Combined Playlist")
        .toolbar {
            if !playableItems.isEmpty {
                Button {
                    let shuffled = playableItems.shuffled()
                    playerVM.currentPlaylistID = nil
                    playerVM.play(item: shuffled[0], in: shuffled)
                } label: {
                    Label("Shuffle", systemImage: "shuffle")
                }
            }
        }
    }
}
