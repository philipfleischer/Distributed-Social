//
//  ImportView.swift
//  Distributed-Social
//

import SwiftUI
import SwiftData

struct ImportView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var mediaLibraryService: MediaLibraryService
    @StateObject private var viewModel = ImportViewModel(fileImportService: FileImportService())

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Local file import section
                    VStack(spacing: 12) {
                        Image(systemName: "square.and.arrow.down.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.deepSky)

                        Text("Import Local Files")
                            .font(.title2).fontWeight(.semibold)

                        Text("Import MP3, M4A, WAV, MP4, and MOV files from the Files app. You can select several at once.")
                            .font(.subheadline)
                            .foregroundStyle(Color.inkSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button("Choose from Files") {
                            viewModel.presentPicker()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.deepSky)
                        .controlSize(.large)
                    }

                    Divider()

                    // Folder-as-playlist import section
                    VStack(spacing: 12) {
                        Image(systemName: "folder.fill.badge.plus")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.deepSky)

                        Text("Import Folder as Playlist")
                            .font(.title2).fontWeight(.semibold)

                        Text("Pick a folder (e.g. an unzipped playlist) — every song inside is imported in order and a playlist with the folder's name is created.")
                            .font(.subheadline)
                            .foregroundStyle(Color.inkSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button("Choose Folder") {
                            viewModel.presentFolderPicker()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.deepSky)
                        .controlSize(.large)
                    }

                    Divider()

                    // URL Import placeholder section
                    VStack(spacing: 12) {
                        Image(systemName: "link.circle")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.inkSecondary)

                        Text("URL Import")
                            .font(.title3).fontWeight(.semibold)

                        Text("Reserved for future use with lawful direct media URLs or local conversion support.")
                            .font(.subheadline)
                            .foregroundStyle(Color.inkSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button("Conversion module not implemented yet") { }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .disabled(true)
                    }

                    // State feedback
                    stateFeedback
                }
                .padding(.top, 24)
                .padding(.bottom, 120) // clear the mini player
                .frame(maxWidth: .infinity)
            }
            .summerBackground()
            .navigationTitle("Import")
            .sheet(isPresented: $viewModel.isPickerPresented) {
                DocumentPickerWrapper(mode: .files) { urls in
                    Task {
                        await viewModel.handlePickedFiles(urls) { item in
                            modelContext.insert(item)
                        }
                    }
                }
            }
            .sheet(isPresented: $viewModel.isFolderPickerPresented) {
                DocumentPickerWrapper(mode: .folder) { urls in
                    guard let folderURL = urls.first else { return }
                    Task {
                        await viewModel.handlePickedFolder(folderURL) { name, items in
                            createPlaylist(named: name, with: items)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var stateFeedback: some View {
        switch viewModel.state {
        case .importing(let current, let total):
            VStack(spacing: 8) {
                ProgressView(value: total > 0 ? Double(current) / Double(total) : 0)
                    .tint(.deepSky)
                    .padding(.horizontal, 48)
                Text(total > 0 ? "Importing \(current) of \(total)…" : "Preparing import…")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSecondary)
            }
        case .success(let message):
            Label(message, systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        case .error(let message):
            Label(message, systemImage: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        case .idle:
            EmptyView()
        }
    }

    /// Inserts the imported items and builds a playlist from them, in order.
    private func createPlaylist(named name: String, with items: [MediaItem]) {
        guard !items.isEmpty else { return }
        // A folder of videos becomes a video playlist; anything mixed → audio.
        let mediaType: MediaType = items.allSatisfy { $0.mediaType == .video } ? .video : .audio
        let playlist = mediaLibraryService.createPlaylist(name: name, mediaType: mediaType, in: modelContext)
        for item in items {
            modelContext.insert(item)
            mediaLibraryService.addItem(item, toPlaylist: playlist, in: modelContext)
        }
    }
}
