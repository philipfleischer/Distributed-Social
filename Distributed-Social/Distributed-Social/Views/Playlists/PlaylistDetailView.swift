//
//  PlaylistDetailView.swift
//  Distributed-Social
//

import SwiftUI
import SwiftData

struct PlaylistDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var themeStore: ThemeStore
    let playlist: Playlist

    private var theme: AppTheme { themeStore.theme }

    private var sortedItems: [PlaylistItem] {
        playlist.sortedItems
    }

    var body: some View {
        List {
            if sortedItems.isEmpty {
                ContentUnavailableView(
                    "Empty Playlist",
                    systemImage: "list.bullet",
                    description: Text("Add items from the \(playlist.mediaType == .audio ? "Audio" : "Video") library using the context menu.")
                )
            } else {
                ForEach(sortedItems) { pi in
                    if let item = pi.mediaItem {
                        let isCurrent = playerVM.currentItem?.id == item.id
                        HStack(spacing: 10) {
                            Text("\(pi.sortOrder + 1)")
                                .foregroundStyle(theme.textSecondary)
                                .frame(width: 24)
                            // Album/song cover between the number and title.
                            MediaArtworkView(item: item, size: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                // Long titles slide instead of wrapping.
                                MarqueeText(
                                    text: item.displayName,
                                    font: .body.weight(isCurrent ? .semibold : .regular),
                                    color: isCurrent ? theme.textHighlight : theme.textPrimary
                                )
                                if let artist = item.artist {
                                    Text(artist)
                                        .font(.caption)
                                        .foregroundStyle(theme.textSecondary)
                                        .lineLimit(1)
                                }
                            }
                            if isCurrent {
                                Image(systemName: "waveform")
                                    .foregroundStyle(theme.textPrimary)
                                    .symbolEffect(.variableColor.iterative, isActive: playerVM.isPlaying)
                            }
                            Text(item.duration.formattedTime)
                                .font(.caption)
                                .foregroundStyle(theme.textSecondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            let queue = sortedItems.compactMap { $0.mediaItem }
                            registerPlay(of: item)
                            playerVM.play(item: item, in: queue)
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                playerVM.addToQueue(item)
                            } label: {
                                Label("Queue", systemImage: "text.append")
                            }
                            .tint(.green)
                        }
                    }
                }
                .onDelete { offsets in
                    for i in offsets {
                        modelContext.delete(sortedItems[i])
                    }
                    renumber()
                }
                .onMove { from, to in
                    var items = sortedItems
                    items.move(fromOffsets: from, toOffset: to)
                    for (index, pi) in items.enumerated() {
                        pi.sortOrder = index
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, 120, for: .scrollContent) // clear the mini player
        .summerBackground()
        .navigationTitle(playlist.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !sortedItems.isEmpty { EditButton() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if !sortedItems.isEmpty {
                    Button {
                        let items = sortedItems.compactMap { $0.mediaItem }
                        if let first = items.first {
                            registerPlay(of: first)
                            playerVM.play(item: first, in: items)
                        }
                    } label: {
                        Label("Play", systemImage: "play.fill")
                    }
                }
            }
        }
    }

    /// Records playback stats used by the Home page (recently played / popular)
    /// and marks this playlist as the one currently playing.
    private func registerPlay(of item: MediaItem) {
        playlist.lastPlayedItemId = item.id
        playlist.lastPlayedDate = Date()
        playlist.playCount += 1
        playerVM.currentPlaylistID = playlist.id
    }

    private func renumber() {
        for (index, pi) in playlist.sortedItems.enumerated() {
            pi.sortOrder = index
        }
    }
}
