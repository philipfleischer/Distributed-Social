//
//  FolderDetailView.swift
//  Distributed-Social
//

import SwiftUI
import SwiftData

struct FolderDetailView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    let folder: Folder

    private var items: [MediaItem] {
        (folder.items ?? []).sorted { $0.dateImported > $1.dateImported }
    }

    var body: some View {
        List {
            if items.isEmpty {
                ContentUnavailableView(
                    "Empty Folder",
                    systemImage: "folder",
                    description: Text("Assign items to this folder from the library context menu.")
                )
            } else {
                ForEach(items) { item in
                    HStack {
                        Image(systemName: item.mediaType.systemImage)
                            .foregroundStyle(Color.deepSky)
                            .frame(width: 32)
                        Text(item.displayName)
                        Spacer()
                        Text(item.duration.formattedTime)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        playerVM.play(item: item, in: items)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .summerBackground()
        .navigationTitle(folder.name)
    }
}
