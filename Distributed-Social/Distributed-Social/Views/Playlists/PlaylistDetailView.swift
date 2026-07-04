//
//  PlaylistDetailView.swift
//  Distributed-Social
//

import SwiftUI
import SwiftData

struct PlaylistDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var playerVM: PlayerViewModel
    let playlist: Playlist

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
                        HStack {
                            Text("\(pi.sortOrder + 1)")
                                .foregroundStyle(.secondary)
                                .frame(width: 28)
                            Text(item.displayName)
                            Spacer()
                            Text(item.duration.formattedTime)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            let queue = sortedItems.compactMap { $0.mediaItem }
                            registerPlay(of: item)
                            playerVM.play(item: item, in: queue)
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

    /// Records playback stats used by the Home page (recently played / popular).
    private func registerPlay(of item: MediaItem) {
        playlist.lastPlayedItemId = item.id
        playlist.lastPlayedDate = Date()
        playlist.playCount += 1
    }

    private func renumber() {
        for (index, pi) in playlist.sortedItems.enumerated() {
            pi.sortOrder = index
        }
    }
}
