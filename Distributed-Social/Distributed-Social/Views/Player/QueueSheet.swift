//
//  QueueSheet.swift
//  Distributed-Social
//
//  Spotify-style two-part queue: "In Queue" holds manually queued songs
//  (FIFO, always play first); "Next Up" is the natural continuation of the
//  current context. Rows can be tapped to jump, dragged to reorder, and
//  swiped to remove — within their own section.
//

import SwiftUI

struct QueueSheet: View {
    @Environment(PlayerViewModel.self) private var playerVM
    @EnvironmentObject var themeStore: ThemeStore
    @Environment(\.dismiss) private var dismiss

    private var theme: AppTheme { themeStore.theme }

    var body: some View {
        NavigationStack {
            Group {
                if playerVM.queuedItems.isEmpty && playerVM.upNext.isEmpty {
                    ContentUnavailableView(
                        "Queue Is Empty",
                        systemImage: "list.number",
                        description: Text("Use “Play Next” or “Add to Queue” on a song to line it up.")
                    )
                } else {
                    List {
                        if !playerVM.queuedItems.isEmpty {
                            Section("In Queue") {
                                ForEach(playerVM.queuedItems) { item in
                                    queueRow(for: item)
                                }
                                .onDelete { playerVM.removeFromQueued(at: $0) }
                                .onMove { playerVM.moveQueued(fromOffsets: $0, toOffset: $1) }
                            }
                        }
                        if !playerVM.upNext.isEmpty {
                            Section("Next Up") {
                                ForEach(playerVM.upNext) { item in
                                    queueRow(for: item)
                                }
                                .onDelete { playerVM.removeFromUpNext(at: $0) }
                                .onMove { playerVM.moveUpNext(fromOffsets: $0, toOffset: $1) }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .summerBackground()
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !(playerVM.queuedItems.isEmpty && playerVM.upNext.isEmpty) {
                        EditButton()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func queueRow(for item: MediaItem) -> some View {
        HStack(spacing: 12) {
            MediaArtworkView(item: item, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                if let artist = item.artist {
                    Text(artist)
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(item.duration.formattedTime)
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            playerVM.jump(to: item)
        }
        .listRowBackground(Color.clear)
    }
}
