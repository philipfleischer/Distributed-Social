//
//  ImportView.swift
//  Distributed-Social
//

import SwiftUI
import SwiftData

struct ImportView: View {
    @Environment(\.modelContext) private var modelContext
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

                        Text("Import MP3, M4A, WAV, MP4, and MOV files from the Files app.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button("Choose from Files") {
                            viewModel.presentPicker()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.skyBlue)
                        .controlSize(.large)
                    }

                    Divider()

                    // URL Import placeholder section
                    VStack(spacing: 12) {
                        Image(systemName: "link.circle")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)

                        Text("URL Import")
                            .font(.title2).fontWeight(.semibold)

                        Text("Reserved for future use with lawful direct media URLs or local conversion support.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button("Conversion module not implemented yet") { }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .disabled(true)
                    }

                    // State feedback
                    switch viewModel.state {
                    case .loading:
                        ProgressView("Importing…")
                    case .success(let item):
                        Label("Imported: \(item.displayName)", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .error(let msg):
                        Label(msg, systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    case .idle:
                        EmptyView()
                    }
                }
                .padding(.top, 40)
                .frame(maxWidth: .infinity)
            }
            .summerBackground()
            .navigationTitle("Import")
            .sheet(isPresented: $viewModel.isPickerPresented) {
                DocumentPickerWrapper { url in
                    Task {
                        await viewModel.handlePickedURL(url) { item in
                            modelContext.insert(item)
                        }
                    }
                }
            }
        }
    }
}
