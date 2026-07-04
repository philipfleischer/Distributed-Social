//
//  FoldersView.swift
//  Distributed-Social
//

import SwiftUI
import SwiftData

struct FoldersView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var mediaLibraryService: MediaLibraryService
    @Query(sort: \Folder.name) private var folders: [Folder]
    @State private var showCreate = false
    @State private var newName = ""

    var body: some View {
        List {
            if folders.isEmpty {
                ContentUnavailableView(
                    "No Folders",
                    systemImage: "folder",
                    description: Text("Create a folder, then assign items to it from the library context menu.")
                )
            } else {
                ForEach(folders) { folder in
                    NavigationLink {
                        FolderDetailView(folder: folder)
                    } label: {
                        Label(folder.name, systemImage: "folder.fill")
                            .foregroundStyle(Color.deepSky)
                    }
                }
                .onDelete { offsets in
                    for i in offsets { modelContext.delete(folders[i]) }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .summerBackground()
        .navigationTitle("Folders")
        .toolbar {
            Button { showCreate = true } label: { Image(systemName: "plus") }
        }
        .sheet(isPresented: $showCreate) {
            NavigationStack {
                Form { TextField("Folder Name", text: $newName) }
                    .navigationTitle("New Folder")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Create") {
                                mediaLibraryService.createFolder(name: newName, in: modelContext)
                                showCreate = false; newName = ""
                            }.disabled(newName.isEmpty)
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showCreate = false; newName = "" }
                        }
                    }
            }
        }
    }
}
