//
//  SettingsView.swift
//  Distributed-Social
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allItems: [MediaItem]
    @State private var showClearConfirmation = false

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Organization") {
                    NavigationLink {
                        FoldersView()
                    } label: {
                        Label("Folders", systemImage: "folder")
                    }
                }

                Section("Data") {
                    Button(role: .destructive) {
                        showClearConfirmation = true
                    } label: {
                        Label("Clear All Media", systemImage: "trash")
                    }
                }

                Section("Sync") {
                    Label("iCloud Sync (coming soon)", systemImage: "icloud")
                        .foregroundStyle(.secondary)
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    Link(destination: URL(string: Constants.Links.repository)!) {
                        Label("GitHub Repository", systemImage: "link")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .summerBackground()
            .navigationTitle("Settings")
            .confirmationDialog(
                "Delete all imported media?",
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Everything", role: .destructive) { clearAllMedia() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes all imported files, playlists, and folders from the device. This cannot be undone.")
            }
        }
    }

    private func clearAllMedia() {
        let importService = FileImportService()
        for item in allItems {
            try? importService.deleteFile(item)
        }
        // Wipe all model data.
        try? modelContext.delete(model: PlaylistItem.self)
        try? modelContext.delete(model: Playlist.self)
        try? modelContext.delete(model: Folder.self)
        try? modelContext.delete(model: MediaItem.self)
    }
}
