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
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.dismiss) private var dismiss

    private var theme: AppTheme { themeStore.theme }

    var body: some View {
        NavigationStack {
            Group {
                if playerVM.queuedItems.isEmpty && playerVM.upNext.isEmpty {
                    ContentUnavailableView(
                        "Queue Is Empty",
                        systemImage: "list.number",
                        description: Text("Use Play Next or Add to Queue on a song to line it up.")
                    )
                } else {
                    List {
                        if !playerVM.queuedItems.isEmpty {
                            Section {
                                ForEach(playerVM.queuedItems) { entry in
                                    queueRow(for: entry, isManual: true)
                                }
                                .onDelete { playerVM.removeFromQueued(at: $0) }
                                .onMove { playerVM.moveQueued(fromOffsets: $0, toOffset: $1) }
                            } header: {
                                HStack {
                                    Text("In Queue")
                                    Spacer()
                                    Button("Clear") { playerVM.clearQueue() }
                                        .font(.caption.weight(.semibold))
                                }
                            }
                        }
                        if !playerVM.upNext.isEmpty {
                            Section("Next Up") {
                                ForEach(playerVM.upNext) { entry in
                                    queueRow(for: entry, isManual: false)
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

    private func queueRow(for entry: QueueEntry, isManual: Bool) -> some View {
        let item = entry.item
        return HStack(spacing: 12) {
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
            playerVM.jump(to: entry)
        }
        .contextMenu {
            if isManual {
                Button {
                    playerVM.playNext(item)
                    // Remove this entry from its current position so it isn't duplicated.
                    if let idx = playerVM.queuedItems.firstIndex(where: { $0.id == entry.id }) {
                        playerVM.removeFromQueued(at: IndexSet(integer: idx))
                    }
                } label: {
                    Label("Move to Front", systemImage: "text.line.first.and.arrowtriangle.forward")
                }
                Button(role: .destructive) {
                    if let idx = playerVM.queuedItems.firstIndex(where: { $0.id == entry.id }) {
                        playerVM.removeFromQueued(at: IndexSet(integer: idx))
                    }
                } label: {
                    Label("Remove", systemImage: "minus.circle")
                }
            } else {
                Button { playerVM.playNext(item) } label: {
                    Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                }
            }
        }
        .listRowBackground(Color.clear)
    }
}
