//
//  DocumentPickerWrapper.swift
//  Distributed-Social
//

import SwiftUI
import UniformTypeIdentifiers

struct DocumentPickerWrapper: UIViewControllerRepresentable {

    enum Mode {
        case files    // multi-select media files
        case folder   // single folder (→ playlist)
    }

    let mode: Mode
    let onPick: ([URL]) -> Void

    private var supportedTypes: [UTType] {
        switch mode {
        case .folder:
            return [.folder]
        case .files:
            return [.audio, .movie, .mpeg4Movie, .mp3,
                    UTType("public.m4a-audio"),
                    UTType("com.apple.protected-mpeg-4-audio"),
                    .wav].compactMap { $0 }
        }
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        picker.allowsMultipleSelection = (mode == .files)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController,
                                context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([URL]) -> Void
        init(onPick: @escaping ([URL]) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController,
                            didPickDocumentsAt urls: [URL]) {
            guard !urls.isEmpty else { return }
            onPick(urls)
        }
    }
}
