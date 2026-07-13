//
//  AppDependencies.swift
//  Distributed-Social
//
//  Composition root: builds and owns the long-lived service objects so the
//  @main App struct stays free of dependency-ordering problems.
//

import Foundation

final class AppDependencies {
    let playbackService: PlaybackService
    let fileImportService: FileImportServiceProtocol
    let mediaLibraryService: MediaLibraryService
    let playerViewModel: PlayerViewModel
    let playbackTimeModel: PlaybackTimeModel

    init() {
        playbackService = PlaybackService()
        fileImportService = FileImportService()
        mediaLibraryService = MediaLibraryService(fileImportService: fileImportService)
        playerViewModel = PlayerViewModel(playbackService: playbackService)
        playbackTimeModel = PlaybackTimeModel(playbackService: playbackService)
    }
}
