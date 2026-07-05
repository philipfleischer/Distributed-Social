//
//  QueueSheet.swift
//  Distributed-Social
//
//  Shows the songs coming up after the current one. Rows can be tapped to
//  jump, dragged to reorder, and swiped to remove.
//

import SwiftUI

struct QueueSheet: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var themeStore: ThemeStore
    @Environment(\.dismiss) private var dismiss

    private var theme: AppTheme { themeStore.theme }

    var body: some View {
        NavigationStack {
            Group {
                if playerVM.upNext.isEmpty {
                    ContentUnavailableView(
                        "Queue Is Empty",
                        systemImage: "list.number",
                        description: Text("Use “Play Next” or “Add to Queue” on a song to line it up.")
                    )
                } else {
                    List {
                        Section("Up Next") {
                            ForEach(playerVM.upNext) { item in
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
                            .onDelete { playerVM.removeFromUpNext(at: $0) }
                            .onMove { playerVM.moveUpNext(fromOffsets: $0, toOffset: $1) }
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
                    if !playerVM.upNext.isEmpty { EditButton() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
