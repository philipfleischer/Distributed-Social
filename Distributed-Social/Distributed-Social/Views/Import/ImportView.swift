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
                            .foregroundStyle(Color.skyBlue)

                        Text("Import Local Files")
                            .font(.title2).fontWeight(.semibold)
                            .foregroundStyle(Color.skyBlue)

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
                            .foregroundStyle(Color.skyBlue)

                        Text("Import Folder as Playlist")
                            .font(.title2).fontWeight(.semibold)
                            .foregroundStyle(Color.skyBlue)

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

                    // Import progress
                    if case .importing(let current, let total) = viewModel.state {
                        VStack(spacing: 8) {
                            ProgressView(value: total > 0 ? Double(current) / Double(total) : 0)
                                .tint(.skyBlue)
                                .padding(.horizontal, 48)
                            Text(total > 0 ? "Importing \(current) of \(total)…" : "Preparing import…")
                                .font(.subheadline)
                                .foregroundStyle(Color.inkSecondary)
                        }
                    }
                }
                .padding(.top, 24)
                .padding(.bottom, 120) // clear the mini player
                .frame(maxWidth: .infinity)
            }
            .summerBackground()
            .navigationTitle("Import")
            .overlay(alignment: .top) { toast }
            .animation(.spring(duration: 0.3), value: viewModel.state)
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

    /// Success/error toast that slides in from the top and auto-dismisses
    /// (the view model returns the state to `.idle` after a few seconds).
    @ViewBuilder
    private var toast: some View {
        switch viewModel.state {
        case .success(let message):
            toastLabel(message, systemImage: "checkmark.circle.fill", color: .green)
        case .error(let message):
            toastLabel(message, systemImage: "exclamationmark.circle.fill", color: .red)
        default:
            EmptyView()
        }
    }

    private func toastLabel(_ message: String, systemImage: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
            Text(message)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(color.opacity(0.92))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
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
