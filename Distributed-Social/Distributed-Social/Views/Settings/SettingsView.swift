//
//  SettingsView.swift
//  Distributed-Social
//
//  Theme selection (persisted), import (files / folder-as-playlist), About.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var mediaLibraryService: MediaLibraryService
    @EnvironmentObject var themeStore: ThemeStore
    @StateObject private var importVM = ImportViewModel(fileImportService: FileImportService())

    private var theme: AppTheme { themeStore.theme }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Theme
                Section("Theme") {
                    ForEach(AppTheme.allCases) { candidate in
                        Button {
                            themeStore.theme = candidate
                        } label: {
                            HStack(spacing: 12) {
                                themeSwatch(for: candidate)
                                Text(candidate.displayName)
                                    .foregroundStyle(theme.textPrimary)
                                Spacer()
                                if themeStore.theme == candidate {
                                    Image(systemName: "checkmark")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(theme.textPrimary)
                                }
                            }
                        }
                    }
                }

                // MARK: Import
                Section("Import") {
                    Button {
                        importVM.presentPicker()
                    } label: {
                        Label("Import Files", systemImage: "square.and.arrow.down")
                            .foregroundStyle(theme.textPrimary)
                    }
                    Button {
                        importVM.presentFolderPicker()
                    } label: {
                        Label("Import Folder as Playlist", systemImage: "folder.fill.badge.plus")
                            .foregroundStyle(theme.textPrimary)
                    }
                    if case .importing(let current, let total) = importVM.state {
                        VStack(alignment: .leading, spacing: 6) {
                            ProgressView(value: total > 0 ? Double(current) / Double(total) : 0)
                                .tint(theme.textPrimary)
                            Text(total > 0 ? "Importing \(current) of \(total)…" : "Preparing import…")
                                .font(.subheadline)
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                }

                // MARK: About
                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    Link(destination: URL(string: Constants.Links.repository)!) {
                        Label("GitHub Repository", systemImage: "link")
                            .foregroundStyle(theme.textPrimary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .summerBackground()
            .navigationTitle("Settings")
            .overlay(alignment: .top) { toast }
            .animation(.spring(duration: 0.3), value: importVM.state)
            .sheet(isPresented: $importVM.isPickerPresented) {
                DocumentPickerWrapper(mode: .files) { urls in
                    Task {
                        await importVM.handlePickedFiles(urls) { item in
                            modelContext.insert(item)
                        }
                    }
                }
            }
            .sheet(isPresented: $importVM.isFolderPickerPresented) {
                DocumentPickerWrapper(mode: .folder) { urls in
                    guard let folderURL = urls.first else { return }
                    Task {
                        await importVM.handlePickedFolder(folderURL) { name, items in
                            createPlaylist(named: name, with: items)
                        }
                    }
                }
            }
        }
    }

    /// Small circle previewing a theme's background + accent.
    private func themeSwatch(for candidate: AppTheme) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: candidate.backgroundColors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            Circle()
                .fill(candidate.textPrimary)
                .frame(width: 12, height: 12)
        }
        .frame(width: 30, height: 30)
        .overlay(Circle().strokeBorder(Color.gray.opacity(0.5), lineWidth: 1))
    }

    /// Success/error toast that slides in from the top and auto-dismisses.
    @ViewBuilder
    private var toast: some View {
        switch importVM.state {
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
        let mediaType: MediaType = items.allSatisfy { $0.mediaType == .video } ? .video : .audio
        let playlist = mediaLibraryService.createPlaylist(name: name, mediaType: mediaType, in: modelContext)
        for item in items {
            modelContext.insert(item)
            mediaLibraryService.addItem(item, toPlaylist: playlist, in: modelContext)
        }
    }
}
