# OfflineMediaLibrary — Complete Build Prompt for Claude

## Instructions for Claude

You are about to build a complete, production-quality Swift iOS application from scratch in this Xcode project. Read this entire document before writing a single line of code. Build all files in the order specified. Do not skip sections. Do not leave TODO stubs unless explicitly marked as Phase 2+. Make the app compile and run on a real device.

---

## Project Identity

| Property | Value |
|---|---|
| Product Name | OfflineMediaLibrary |
| Bundle ID | com.philipfleischer.OfflineMediaLibrary |
| Language | Swift |
| UI Framework | SwiftUI |
| Deployment Target | **iOS 17.0** |
| Persistence | **SwiftData** (iOS 17+) |
| Architecture | MVVM + Clean Architecture (Services layer) |
| Repository | https://github.com/philipfleischer/Distributed-Social |

---

## What This App Does

A personal offline media library app — a Spotify/YouTube hybrid for local files only. The user imports MP3, M4A, WAV, MP4, and MOV files from the iOS Files app. They organize them into folders and playlists, and play them with full playback controls. The app works entirely without Wi-Fi after files are imported. It is for personal use but built to portfolio/CV quality, so architecture, naming, and Git hygiene matter.

**Legal constraint:** No YouTube downloading, no DRM circumvention, no platform-violating features. The app only plays local files the user imports themselves. A "URL Import" placeholder screen exists for future lawful use — disabled button only, no implementation.

---

## Xcode Project Setup (Do This First)

1. Create a new Xcode project:
   - Template: iOS → App
   - Product Name: `OfflineMediaLibrary`
   - Bundle Identifier: `com.philipfleischer.OfflineMediaLibrary`
   - Interface: SwiftUI
   - Language: Swift
   - Storage: None (SwiftData is added manually below)
   - Deployment Target: **iOS 17.0**
   - Uncheck "Include Tests" for now

2. In **Signing & Capabilities**, add:
   - **Background Modes** → check `Audio, AirPlay, and Picture in Picture`

3. Add these keys to `Info.plist`:
   ```xml
   <key>UIBackgroundModes</key>
   <array><string>audio</string></array>
   <key>UIFileSharingEnabled</key><true/>
   <key>LSSupportsOpeningDocumentsInPlace</key><true/>
   ```
   `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace` make the app's Documents folder visible in the iOS Files app.

4. Add the **SwiftData** framework: it is built into iOS 17 SDK, no additional imports needed.

---

## File Structure to Create

Create this exact folder structure inside the Xcode project group `OfflineMediaLibrary/`:

```
OfflineMediaLibrary/
├── App/
│   ├── OfflineMediaLibraryApp.swift
│   └── AppDependencies.swift
├── Models/
│   ├── MediaItem.swift
│   ├── Playlist.swift
│   ├── PlaylistItem.swift
│   ├── Folder.swift
│   └── MediaType.swift
├── Services/
│   ├── Protocols/
│   │   ├── MediaLibraryServiceProtocol.swift
│   │   ├── PlaybackServiceProtocol.swift
│   │   └── FileImportServiceProtocol.swift
│   ├── MediaLibraryService.swift
│   ├── PlaybackService.swift
│   └── FileImportService.swift
├── ViewModels/
│   ├── AudioLibraryViewModel.swift
│   ├── VideoLibraryViewModel.swift
│   ├── PlaylistsViewModel.swift
│   ├── PlaylistDetailViewModel.swift
│   ├── PlayerViewModel.swift
│   ├── ImportViewModel.swift
│   ├── FolderViewModel.swift
│   └── SettingsViewModel.swift
├── Views/
│   ├── Root/
│   │   └── ContentView.swift
│   ├── AudioLibrary/
│   │   ├── AudioLibraryView.swift
│   │   └── AudioRowView.swift
│   ├── VideoLibrary/
│   │   ├── VideoLibraryView.swift
│   │   └── VideoRowView.swift
│   ├── Playlists/
│   │   ├── PlaylistsView.swift
│   │   ├── PlaylistDetailView.swift
│   │   └── AddToPlaylistSheet.swift
│   ├── Player/
│   │   ├── FullPlayerView.swift
│   │   ├── MiniPlayerView.swift
│   │   ├── VideoPlayerView.swift
│   │   └── PlayerControlsView.swift
│   ├── Import/
│   │   ├── ImportView.swift
│   │   └── DocumentPickerWrapper.swift
│   ├── Folders/
│   │   ├── FoldersView.swift
│   │   └── FolderDetailView.swift
│   └── Settings/
│       └── SettingsView.swift
├── Utilities/
│   ├── Extensions/
│   │   ├── TimeInterval+Format.swift
│   │   └── URL+MediaHelpers.swift
│   └── Constants.swift
└── Resources/
    └── Assets.xcassets
```

Repository root (outside Xcode project):
```
/
├── OfflineMediaLibrary.xcodeproj/
├── OfflineMediaLibrary/          (above)
├── README.md
├── ARCHITECTURE.md
├── CLAUDE.md
├── ROADMAP.md
├── BUILD_PROMPT.md               (this file)
├── .gitignore
└── .github/
    └── workflows/
        └── ci.yml
```

---

## Data Models (SwiftData)

Use `@Model` macro for SwiftData. All models live in `Models/`.

### `MediaType.swift`
```swift
enum MediaType: String, Codable, CaseIterable {
    case audio
    case video

    var systemImage: String {
        switch self {
        case .audio: return "music.note"
        case .video: return "film"
        }
    }
}
```

### `MediaItem.swift`
```swift
import SwiftData
import Foundation

@Model
final class MediaItem {
    var id: UUID
    var displayName: String
    var filename: String          // relative to Documents/Media/ — never store absolute path
    var mediaTypeRaw: String      // store MediaType.rawValue
    var duration: TimeInterval
    var dateImported: Date
    var lastPosition: TimeInterval
    var folder: Folder?
    var playlistItems: [PlaylistItem]?

    var mediaType: MediaType {
        get { MediaType(rawValue: mediaTypeRaw) ?? .audio }
        set { mediaTypeRaw = newValue.rawValue }
    }

    var localURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Media")
            .appendingPathComponent(filename)
    }

    init(displayName: String, filename: String, mediaType: MediaType,
         duration: TimeInterval, dateImported: Date = Date()) {
        self.id = UUID()
        self.displayName = displayName
        self.filename = filename
        self.mediaTypeRaw = mediaType.rawValue
        self.duration = duration
        self.dateImported = dateImported
        self.lastPosition = 0
    }
}
```

**Key design decision:** Only `filename` (relative path) is persisted. `localURL` is derived at runtime. This prevents stale absolute sandbox paths after reinstalls or iOS updates.

### `Folder.swift`
```swift
import SwiftData
import Foundation

@Model
final class Folder {
    var id: UUID
    var name: String
    var colorHex: String
    var items: [MediaItem]?

    init(name: String, colorHex: String = "#5E5CE6") {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
    }
}
```

### `Playlist.swift`
```swift
import SwiftData
import Foundation

@Model
final class Playlist {
    var id: UUID
    var name: String
    var mediaTypeRaw: String
    var lastPlayedItemId: UUID?
    var lastPlayedPosition: TimeInterval
    var orderedItems: [PlaylistItem]?

    var mediaType: MediaType {
        get { MediaType(rawValue: mediaTypeRaw) ?? .audio }
        set { mediaTypeRaw = newValue.rawValue }
    }

    var sortedItems: [PlaylistItem] {
        (orderedItems ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    init(name: String, mediaType: MediaType) {
        self.id = UUID()
        self.name = name
        self.mediaTypeRaw = mediaType.rawValue
        self.lastPlayedPosition = 0
    }
}
```

### `PlaylistItem.swift`
```swift
import SwiftData
import Foundation

@Model
final class PlaylistItem {
    var id: UUID
    var sortOrder: Int
    var mediaItem: MediaItem?
    var playlist: Playlist?

    init(mediaItem: MediaItem, playlist: Playlist, sortOrder: Int) {
        self.id = UUID()
        self.sortOrder = sortOrder
        self.mediaItem = mediaItem
        self.playlist = playlist
    }
}
```

---

## Services Layer

### Protocols

#### `FileImportServiceProtocol.swift`
```swift
import Foundation

protocol FileImportServiceProtocol {
    func importFile(from sourceURL: URL) async throws -> MediaItem
    func deleteFile(_ item: MediaItem) throws
}
```

#### `PlaybackServiceProtocol.swift`
```swift
import Foundation

enum RepeatMode: String, CaseIterable {
    case off          // no repeat
    case all          // loop entire playlist: last song → first song
    case one          // repeat current song before advancing

    var systemImage: String {
        switch self {
        case .off: return "repeat"
        case .all: return "repeat"
        case .one: return "repeat.1"
        }
    }

    var isActive: Bool { self != .off }

    func next() -> RepeatMode {
        switch self {
        case .off: return .all
        case .all: return .one
        case .one: return .off
        }
    }
}

protocol PlaybackServiceProtocol: AnyObject {
    var currentItem: MediaItem? { get }
    var isPlaying: Bool { get }
    var currentTime: TimeInterval { get }
    var duration: TimeInterval { get }
    var playbackSpeed: Float { get }
    var isShuffleEnabled: Bool { get }
    var repeatMode: RepeatMode { get }

    func play(item: MediaItem, in queue: [MediaItem], startAt position: TimeInterval)
    func togglePlayPause()
    func skip(by seconds: TimeInterval)
    func nextTrack()
    func previousTrack()
    func seek(to position: TimeInterval)
    func setSpeed(_ speed: Float)
    func toggleShuffle()
    func cycleRepeatMode()
    func saveCurrentPosition()
}
```

### `FileImportService.swift`
```swift
import Foundation
import AVFoundation

final class FileImportService: FileImportServiceProtocol {

    private var mediaDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Media")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func importFile(from sourceURL: URL) async throws -> MediaItem {
        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessed { sourceURL.stopAccessingSecurityScopedResource() } }

        // Unique filename prevents collisions on duplicate names
        let uniqueFilename = "\(UUID().uuidString)-\(sourceURL.lastPathComponent)"
        let destination = mediaDirectory.appendingPathComponent(uniqueFilename)

        try FileManager.default.copyItem(at: sourceURL, to: destination)

        let asset = AVURLAsset(url: destination)
        let cmDuration = try await asset.load(.duration)
        let duration = cmDuration.seconds.isNaN ? 0 : cmDuration.seconds

        let mediaType: MediaType = sourceURL.isVideoFile ? .video : .audio
        let displayName = sourceURL.deletingPathExtension().lastPathComponent

        return MediaItem(
            displayName: displayName,
            filename: uniqueFilename,
            mediaType: mediaType,
            duration: duration
        )
    }

    func deleteFile(_ item: MediaItem) throws {
        guard FileManager.default.fileExists(atPath: item.localURL.path) else { return }
        try FileManager.default.removeItem(at: item.localURL)
    }
}
```

### `PlaybackService.swift`

This is the most complex service. Implement it carefully.

```swift
import AVFoundation
import Combine
import UIKit

final class PlaybackService: NSObject, ObservableObject, PlaybackServiceProtocol {

    @Published private(set) var currentItem: MediaItem?
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var playbackSpeed: Float = 1.0
    @Published private(set) var isShuffleEnabled: Bool = false
    @Published private(set) var repeatMode: RepeatMode = .off

    private let player = AVPlayer()
    private var timeObserver: Any?
    private var itemEndObserver: NSObjectProtocol?
    private var resignObserver: NSObjectProtocol?

    private var originalQueue: [MediaItem] = []
    private var activeQueue: [MediaItem] = []
    private var currentIndex: Int = 0

    override init() {
        super.init()
        configureAudioSession()
        addTimeObserver()
        addEndObserver()
        addResignObserver()
    }

    // MARK: - Setup

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[PlaybackService] AVAudioSession error: \(error)")
        }
    }

    private func addTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.currentTime = time.seconds.isNaN ? 0 : time.seconds
        }
    }

    private func addEndObserver() {
        itemEndObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handlePlaybackEnd()
        }
    }

    private func addResignObserver() {
        resignObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.saveCurrentPosition()
        }
    }

    // MARK: - Playback end handling

    private func handlePlaybackEnd() {
        switch repeatMode {
        case .one:
            // Repeat the current song: seek to start and play again
            player.seek(to: .zero)
            player.play()
        case .all:
            // Advance; if at end, loop back to first
            let nextIndex = currentIndex + 1
            if nextIndex < activeQueue.count {
                loadItem(at: nextIndex, autoPlay: true)
            } else {
                loadItem(at: 0, autoPlay: true)
            }
        case .off:
            // Advance only if not at end
            let nextIndex = currentIndex + 1
            if nextIndex < activeQueue.count {
                loadItem(at: nextIndex, autoPlay: true)
            } else {
                isPlaying = false
            }
        }
    }

    // MARK: - Protocol implementation

    func play(item: MediaItem, in queue: [MediaItem], startAt position: TimeInterval = 0) {
        originalQueue = queue
        activeQueue = isShuffleEnabled ? queue.shuffled() : queue

        if let index = activeQueue.firstIndex(where: { $0.id == item.id }) {
            currentIndex = index
        } else {
            currentIndex = 0
        }
        loadItem(at: currentIndex, autoPlay: true, startAt: position)
    }

    func togglePlayPause() {
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            player.rate = playbackSpeed
            isPlaying = true
        }
    }

    func skip(by seconds: TimeInterval) {
        let newTime = max(0, min(currentTime + seconds, duration))
        seek(to: newTime)
    }

    func nextTrack() {
        guard !activeQueue.isEmpty else { return }
        let nextIndex = (currentIndex + 1) % activeQueue.count
        loadItem(at: nextIndex, autoPlay: isPlaying)
    }

    func previousTrack() {
        guard !activeQueue.isEmpty else { return }
        if currentTime > 3 {
            // If more than 3s in, restart current track
            seek(to: 0)
        } else {
            let prevIndex = currentIndex == 0 ? activeQueue.count - 1 : currentIndex - 1
            loadItem(at: prevIndex, autoPlay: isPlaying)
        }
    }

    func seek(to position: TimeInterval) {
        let time = CMTime(seconds: position, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: time)
    }

    func setSpeed(_ speed: Float) {
        playbackSpeed = speed
        if isPlaying { player.rate = speed }
    }

    func toggleShuffle() {
        isShuffleEnabled.toggle()
        let currentItemId = currentItem?.id
        if isShuffleEnabled {
            activeQueue = originalQueue.shuffled()
        } else {
            activeQueue = originalQueue
        }
        if let id = currentItemId,
           let newIndex = activeQueue.firstIndex(where: { $0.id == id }) {
            currentIndex = newIndex
        }
    }

    func cycleRepeatMode() {
        repeatMode = repeatMode.next()
    }

    func saveCurrentPosition() {
        currentItem?.lastPosition = currentTime
    }

    // MARK: - Private helpers

    private func loadItem(at index: Int, autoPlay: Bool, startAt position: TimeInterval = 0) {
        guard index < activeQueue.count else { return }
        let item = activeQueue[index]
        currentIndex = index
        currentItem = item

        let playerItem = AVPlayerItem(url: item.localURL)
        player.replaceCurrentItem(with: playerItem)

        if position > 0 {
            let time = CMTime(seconds: position, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            player.seek(to: time)
        }

        // Load duration
        Task {
            if let cmDuration = try? await playerItem.asset.load(.duration) {
                await MainActor.run {
                    self.duration = cmDuration.seconds.isNaN ? 0 : cmDuration.seconds
                }
            }
        }

        if autoPlay {
            player.play()
            player.rate = playbackSpeed
            isPlaying = true
        }
    }

    deinit {
        if let obs = timeObserver { player.removeTimeObserver(obs) }
        if let obs = itemEndObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = resignObserver { NotificationCenter.default.removeObserver(obs) }
    }
}
```

### `MediaLibraryService.swift`

A thin coordinator that ViewModels use to trigger SwiftData mutations. ViewModels that have `@Query` access the data directly; this service handles cross-cutting operations.

```swift
import SwiftData
import Foundation

final class MediaLibraryService: ObservableObject {
    // SwiftData operations are driven by ModelContext passed from the view layer.
    // This service holds shared computed state and cross-cutting helpers.

    func createFolder(name: String, colorHex: String = "#5E5CE6",
                      in context: ModelContext) -> Folder {
        let folder = Folder(name: name, colorHex: colorHex)
        context.insert(folder)
        return folder
    }

    func createPlaylist(name: String, mediaType: MediaType,
                        in context: ModelContext) -> Playlist {
        let playlist = Playlist(name: name, mediaType: mediaType)
        context.insert(playlist)
        return playlist
    }

    func addItem(_ item: MediaItem, toPlaylist playlist: Playlist,
                 in context: ModelContext) {
        let nextOrder = (playlist.orderedItems?.count ?? 0)
        let pi = PlaylistItem(mediaItem: item, playlist: playlist, sortOrder: nextOrder)
        context.insert(pi)
    }

    func deleteMediaItem(_ item: MediaItem, fileImportService: FileImportServiceProtocol,
                         in context: ModelContext) {
        try? fileImportService.deleteFile(item)
        context.delete(item)
    }
}
```

---

## ViewModels

### `PlayerViewModel.swift`

The bridge between `PlaybackService` and all player UI. Observe `PlaybackService` via Combine.

```swift
import Combine
import Foundation

final class PlayerViewModel: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentItem: MediaItem? = nil
    @Published var playbackSpeed: Float = 1.0
    @Published var isShuffleEnabled: Bool = false
    @Published var repeatMode: RepeatMode = .off
    @Published var isFullPlayerPresented: Bool = false

    private let playbackService: PlaybackService
    private var cancellables = Set<AnyCancellable>()

    init(playbackService: PlaybackService) {
        self.playbackService = playbackService
        bindToService()
    }

    private func bindToService() {
        playbackService.$isPlaying.assign(to: &$isPlaying)
        playbackService.$currentTime.assign(to: &$currentTime)
        playbackService.$duration.assign(to: &$duration)
        playbackService.$currentItem.assign(to: &$currentItem)
        playbackService.$playbackSpeed.assign(to: &$playbackSpeed)
        playbackService.$isShuffleEnabled.assign(to: &$isShuffleEnabled)
        playbackService.$repeatMode.assign(to: &$repeatMode)
    }

    func togglePlayPause() { playbackService.togglePlayPause() }
    func skip(by s: TimeInterval) { playbackService.skip(by: s) }
    func nextTrack() { playbackService.nextTrack() }
    func previousTrack() { playbackService.previousTrack() }
    func seek(to t: TimeInterval) { playbackService.seek(to: t) }
    func setSpeed(_ s: Float) { playbackService.setSpeed(s) }
    func toggleShuffle() { playbackService.toggleShuffle() }
    func cycleRepeatMode() { playbackService.cycleRepeatMode() }

    func play(item: MediaItem, in queue: [MediaItem]) {
        playbackService.play(item: item, in: queue, startAt: item.lastPosition)
        isFullPlayerPresented = true
    }
}
```

### `AudioLibraryViewModel.swift`
```swift
import Foundation
import Combine

final class AudioLibraryViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var selectedFolderId: UUID? = nil

    func filteredItems(_ all: [MediaItem]) -> [MediaItem] {
        var items = all.filter { $0.mediaType == .audio }
        if let fid = selectedFolderId {
            items = items.filter { $0.folder?.id == fid }
        }
        if !searchText.isEmpty {
            items = items.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
        return items.sorted { $0.dateImported > $1.dateImported }
    }
}
```

`VideoLibraryViewModel.swift` is identical but filters `mediaType == .video`.

### `ImportViewModel.swift`
```swift
import Foundation

enum ImportState {
    case idle
    case loading
    case success(MediaItem)
    case error(String)
}

@MainActor
final class ImportViewModel: ObservableObject {
    @Published var isPickerPresented: Bool = false
    @Published var state: ImportState = .idle

    private let fileImportService: FileImportServiceProtocol

    init(fileImportService: FileImportServiceProtocol) {
        self.fileImportService = fileImportService
    }

    func presentPicker() { isPickerPresented = true }

    func handlePickedURL(_ url: URL, addToLibrary: (MediaItem) -> Void) async {
        state = .loading
        do {
            let item = try await fileImportService.importFile(from: url)
            addToLibrary(item)
            state = .success(item)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}
```

---

## Views

### `App/OfflineMediaLibraryApp.swift`
```swift
import SwiftUI
import SwiftData

@main
struct OfflineMediaLibraryApp: App {
    private let playbackService = PlaybackService()
    private let fileImportService = FileImportService()
    private let mediaLibraryService = MediaLibraryService()

    @StateObject private var playerViewModel: PlayerViewModel

    init() {
        let ps = PlaybackService()
        _playerViewModel = StateObject(wrappedValue: PlayerViewModel(playbackService: ps))
        // Note: because PlaybackService and PlayerViewModel share the same instance,
        // store playbackService as a property and pass it. Clean this up:
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(playerViewModel)
                .environmentObject(mediaLibraryService)
        }
        .modelContainer(for: [MediaItem.self, Playlist.self, PlaylistItem.self, Folder.self])
    }
}
```

**Note to Claude:** The init above has a dependency ordering problem. Fix it cleanly: declare `playbackService` as a `let` stored property at the top of the struct, then create `playerViewModel` using it. In SwiftUI `App`, stored properties are initialized before `body` runs.

### `App/AppDependencies.swift`

A clean composition root:
```swift
import Foundation

final class AppDependencies {
    let playbackService: PlaybackService
    let fileImportService: FileImportServiceProtocol
    let mediaLibraryService: MediaLibraryService
    let playerViewModel: PlayerViewModel

    init() {
        playbackService = PlaybackService()
        fileImportService = FileImportService()
        mediaLibraryService = MediaLibraryService()
        playerViewModel = PlayerViewModel(playbackService: playbackService)
    }
}
```

Update `OfflineMediaLibraryApp.swift` to use:
```swift
@main
struct OfflineMediaLibraryApp: App {
    private let deps = AppDependencies()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(deps.playerViewModel)
                .environmentObject(deps.mediaLibraryService)
                .environment(\.fileImportService, deps.fileImportService)
        }
        .modelContainer(for: [MediaItem.self, Playlist.self, PlaylistItem.self, Folder.self])
    }
}
```

Use an `EnvironmentKey` for `fileImportService` or inject it via `@EnvironmentObject` with a wrapper. Keep it simple.

### `Views/Root/ContentView.swift`

```swift
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var playerVM: PlayerViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                AudioLibraryView()
                    .tabItem { Label("Audio", systemImage: "music.note.list") }
                VideoLibraryView()
                    .tabItem { Label("Video", systemImage: "film") }
                PlaylistsView()
                    .tabItem { Label("Playlists", systemImage: "list.bullet") }
                ImportView()
                    .tabItem { Label("Import", systemImage: "square.and.arrow.down") }
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gear") }
            }

            if playerVM.currentItem != nil {
                MiniPlayerView()
                    .padding(.bottom, 49) // clear the tab bar
            }
        }
        .sheet(isPresented: $playerVM.isFullPlayerPresented) {
            FullPlayerView()
        }
    }
}
```

### `Views/Player/MiniPlayerView.swift`

```swift
import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject var playerVM: PlayerViewModel

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: playerVM.currentItem?.mediaType.systemImage ?? "music.note")
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 44, height: 44)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(playerVM.currentItem?.displayName ?? "")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(playerVM.currentTime.formattedTime + " / " + playerVM.duration.formattedTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button { playerVM.previousTrack() } label: {
                Image(systemName: "backward.fill")
            }
            Button { playerVM.togglePlayPause() } label: {
                Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
            }
            Button { playerVM.nextTrack() } label: {
                Image(systemName: "forward.fill")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 8)
        .shadow(radius: 4)
        .onTapGesture { playerVM.isFullPlayerPresented = true }
    }
}
```

### `Views/Player/PlayerControlsView.swift`

Shared controls used by the full player. Includes: shuffle, previous, play/pause, next, repeat. And below that: skip buttons, speed picker.

```swift
import SwiftUI

struct PlayerControlsView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @State private var isScrubbing = false
    @State private var scrubPosition: TimeInterval = 0

    var body: some View {
        VStack(spacing: 20) {
            // Progress bar
            VStack(spacing: 4) {
                Slider(
                    value: Binding(
                        get: { isScrubbing ? scrubPosition : playerVM.currentTime },
                        set: { scrubPosition = $0 }
                    ),
                    in: 0...(playerVM.duration > 0 ? playerVM.duration : 1)
                ) { editing in
                    isScrubbing = editing
                    if !editing { playerVM.seek(to: scrubPosition) }
                }
                HStack {
                    Text(playerVM.currentTime.formattedTime)
                        .font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Text(playerVM.duration.formattedTime)
                        .font(.caption).foregroundColor(.secondary)
                }
            }

            // Main controls row: shuffle | prev | play/pause | next | repeat
            HStack(spacing: 32) {
                Button { playerVM.toggleShuffle() } label: {
                    Image(systemName: "shuffle")
                        .foregroundColor(playerVM.isShuffleEnabled ? .accentColor : .primary)
                }
                Button { playerVM.previousTrack() } label: {
                    Image(systemName: "backward.fill").font(.title2)
                }
                Button { playerVM.togglePlayPause() } label: {
                    Image(systemName: playerVM.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 64))
                }
                Button { playerVM.nextTrack() } label: {
                    Image(systemName: "forward.fill").font(.title2)
                }
                // Repeat button — cycles through: off → all → one → off
                Button { playerVM.cycleRepeatMode() } label: {
                    ZStack {
                        Image(systemName: playerVM.repeatMode.systemImage)
                            .foregroundColor(playerVM.repeatMode.isActive ? .accentColor : .primary)
                        // Show subtle dot below icon when repeat.one is active
                        if playerVM.repeatMode == .one {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 5, height: 5)
                                .offset(y: 12)
                        }
                    }
                }
            }

            // Skip buttons row
            HStack(spacing: 48) {
                Button { playerVM.skip(by: -15) } label: {
                    Image(systemName: "gobackward.15")
                }
                Button { playerVM.skip(by: 15) } label: {
                    Image(systemName: "goforward.15")
                }
            }

            // Speed picker
            Picker("Speed", selection: Binding(
                get: { playerVM.playbackSpeed },
                set: { playerVM.setSpeed($0) }
            )) {
                Text("0.75×").tag(Float(0.75))
                Text("1×").tag(Float(1.0))
                Text("1.25×").tag(Float(1.25))
                Text("1.5×").tag(Float(1.5))
                Text("2×").tag(Float(2.0))
            }
            .pickerStyle(.segmented)
        }
        .padding()
    }
}
```

### `Views/Player/FullPlayerView.swift`

```swift
import SwiftUI

struct FullPlayerView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Artwork / icon
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.secondarySystemBackground))
                        .frame(width: 240, height: 240)
                    Image(systemName: playerVM.currentItem?.mediaType.systemImage ?? "music.note")
                        .font(.system(size: 80))
                        .foregroundColor(.accentColor)
                }
                .padding(.top, 20)

                // Title
                Text(playerVM.currentItem?.displayName ?? "")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Video embed (only for video items)
                if playerVM.currentItem?.mediaType == .video {
                    // VideoPlayerView injected from PlaybackService
                    // See VideoPlayerView.swift
                }

                PlayerControlsView()

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down")
                    }
                }
            }
        }
    }
}
```

### `Views/Player/VideoPlayerView.swift`

```swift
import SwiftUI
import AVKit

struct VideoPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = player
        vc.showsPlaybackControls = false
        return vc
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}
```

To expose the player from `PlaybackService`, add a `var player: AVPlayer { player }` getter (rename the private property or use internal access).

### `Views/Import/DocumentPickerWrapper.swift`

```swift
import SwiftUI
import UniformTypeIdentifiers

struct DocumentPickerWrapper: UIViewControllerRepresentable {

    let onPick: (URL) -> Void

    private var supportedTypes: [UTType] {
        [.audio, .movie, .mp3,
         UTType("public.m4a-audio"),
         UTType("com.apple.protected-mpeg-4-audio"),
         .wav].compactMap { $0 }
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController,
                                context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController,
                            didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}
```

### `Views/Import/ImportView.swift`

```swift
import SwiftUI
import SwiftData

struct ImportView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var mediaLibraryService: MediaLibraryService
    @StateObject private var viewModel: ImportViewModel

    // Inject via init or environment key
    init(fileImportService: FileImportServiceProtocol) {
        _viewModel = StateObject(wrappedValue: ImportViewModel(fileImportService: fileImportService))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Local file import section
                VStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.down.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor)

                    Text("Import Local Files")
                        .font(.title2).fontWeight(.semibold)

                    Text("Import MP3, M4A, WAV, MP4, and MOV files from the Files app.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button("Choose from Files") {
                        viewModel.presentPicker()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

                Divider()

                // URL Import placeholder section
                VStack(spacing: 12) {
                    Image(systemName: "link.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("URL Import")
                        .font(.title2).fontWeight(.semibold)

                    Text("Reserved for future use with lawful direct media URLs or local conversion support.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
                        .foregroundColor(.green)
                case .error(let msg):
                    Label(msg, systemImage: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                case .idle:
                    EmptyView()
                }

                Spacer()
            }
            .padding(.top, 40)
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
```

### `Views/AudioLibrary/AudioLibraryView.swift`

```swift
import SwiftUI
import SwiftData

struct AudioLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var mediaLibraryService: MediaLibraryService
    @Query(sort: \MediaItem.dateImported, order: .reverse) private var allItems: [MediaItem]
    @StateObject private var viewModel = AudioLibraryViewModel()

    var body: some View {
        NavigationStack {
            let items = viewModel.filteredItems(allItems)

            Group {
                if items.isEmpty {
                    ContentUnavailableView(
                        "No Audio Files",
                        systemImage: "music.note.list",
                        description: Text("Import MP3, M4A, or WAV files from the Import tab.")
                    )
                } else {
                    List(items) { item in
                        AudioRowView(item: item) {
                            playerVM.play(item: item, in: items)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                mediaLibraryService.deleteMediaItem(item,
                                    fileImportService: FileImportService(),
                                    in: modelContext)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Audio")
            .searchable(text: $viewModel.searchText)
        }
    }
}
```

### `Views/AudioLibrary/AudioRowView.swift`

```swift
import SwiftUI

struct AudioRowView: View {
    let item: MediaItem
    let onPlay: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "music.note")
                .frame(width: 40, height: 40)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.body)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(item.duration.formattedTime)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if item.lastPosition > 5 {
                        Text("· \(item.lastPosition.formattedTime) played")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            Button { onPlay() } label: {
                Image(systemName: "play.fill")
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture { onPlay() }
    }
}
```

Build `VideoLibraryView` and `VideoRowView` following exactly the same pattern with `.video` filtering.

### `Views/Playlists/PlaylistsView.swift`

```swift
import SwiftUI
import SwiftData

struct PlaylistsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var mediaLibraryService: MediaLibraryService
    @Query private var playlists: [Playlist]
    @State private var showCreateSheet = false
    @State private var newName = ""
    @State private var newType: MediaType = .audio

    var body: some View {
        NavigationStack {
            List {
                Section("Audio Playlists") {
                    ForEach(playlists.filter { $0.mediaType == .audio }) { playlist in
                        NavigationLink(playlist.name) {
                            PlaylistDetailView(playlist: playlist)
                        }
                    }
                }
                Section("Video Playlists") {
                    ForEach(playlists.filter { $0.mediaType == .video }) { playlist in
                        NavigationLink(playlist.name) {
                            PlaylistDetailView(playlist: playlist)
                        }
                    }
                }
            }
            .navigationTitle("Playlists")
            .toolbar {
                Button { showCreateSheet = true } label: {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                NavigationStack {
                    Form {
                        TextField("Playlist Name", text: $newName)
                        Picker("Type", selection: $newType) {
                            Text("Audio").tag(MediaType.audio)
                            Text("Video").tag(MediaType.video)
                        }
                    }
                    .navigationTitle("New Playlist")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Create") {
                                mediaLibraryService.createPlaylist(
                                    name: newName,
                                    mediaType: newType,
                                    in: modelContext)
                                showCreateSheet = false
                                newName = ""
                            }
                            .disabled(newName.isEmpty)
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showCreateSheet = false }
                        }
                    }
                }
            }
        }
    }
}
```

### `Views/Playlists/PlaylistDetailView.swift`

```swift
import SwiftUI
import SwiftData

struct PlaylistDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var mediaLibraryService: MediaLibraryService
    let playlist: Playlist

    private var sortedItems: [PlaylistItem] {
        playlist.sortedItems
    }

    var body: some View {
        List {
            if sortedItems.isEmpty {
                ContentUnavailableView("Empty Playlist", systemImage: "list.bullet",
                    description: Text("Add items from the \(playlist.mediaType == .audio ? "Audio" : "Video") library."))
            } else {
                ForEach(sortedItems) { pi in
                    if let item = pi.mediaItem {
                        HStack {
                            Text("\(pi.sortOrder + 1)")
                                .foregroundColor(.secondary)
                                .frame(width: 28)
                            Text(item.displayName)
                            Spacer()
                            Text(item.duration.formattedTime)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            let queue = sortedItems.compactMap { $0.mediaItem }
                            playerVM.play(item: item, in: queue)
                        }
                    }
                }
                .onDelete { offsets in
                    for i in offsets {
                        modelContext.delete(sortedItems[i])
                    }
                }
                .onMove { from, to in
                    var items = sortedItems
                    items.move(fromOffsets: from, toOffset: to)
                    for (index, pi) in items.enumerated() {
                        pi.sortOrder = index
                    }
                }
            }
        }
        .navigationTitle(playlist.name)
        .toolbar {
            if !sortedItems.isEmpty {
                Button {
                    let items = sortedItems.compactMap { $0.mediaItem }
                    if let first = items.first {
                        playerVM.play(item: first, in: items)
                    }
                } label: {
                    Label("Play", systemImage: "play.fill")
                }
            }
        }
        .environment(\.editMode, .constant(.active))
    }
}
```

### `Views/Folders/FoldersView.swift`

```swift
import SwiftUI
import SwiftData

struct FoldersView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var mediaLibraryService: MediaLibraryService
    @Query private var folders: [Folder]
    @State private var showCreate = false
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(folders) { folder in
                    NavigationLink(folder.name) {
                        FolderDetailView(folder: folder)
                    }
                }
                .onDelete { offsets in
                    for i in offsets { modelContext.delete(folders[i]) }
                }
            }
            .navigationTitle("Folders")
            .toolbar {
                Button { showCreate = true } label: { Image(systemName: "plus") }
            }
            .sheet(isPresented: $showCreate) {
                NavigationStack {
                    Form { TextField("Folder Name", text: $newName) }
                    .navigationTitle("New Folder")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Create") {
                                mediaLibraryService.createFolder(name: newName, in: modelContext)
                                showCreate = false; newName = ""
                            }.disabled(newName.isEmpty)
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showCreate = false }
                        }
                    }
                }
            }
        }
    }
}
```

Add `FolderDetailView` that shows items belonging to the folder. Add folder assignment from item context menu in `AudioLibraryView` and `VideoLibraryView`.

### `Views/Settings/SettingsView.swift`

Simple settings screen. Include:
- App version display
- "Clear all media" dangerous action (confirmation dialog)
- About section linking to the GitHub repo
- Future: iCloud sync toggle (placeholder, disabled)

---

## Utilities

### `Utilities/Extensions/TimeInterval+Format.swift`
```swift
extension TimeInterval {
    var formattedTime: String {
        guard !isNaN && !isInfinite else { return "0:00" }
        let total = Int(self)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s)
                     : String(format: "%d:%02d", m, s)
    }
}
```

### `Utilities/Extensions/URL+MediaHelpers.swift`
```swift
import Foundation

extension URL {
    var isVideoFile: Bool {
        ["mp4", "mov", "m4v"].contains(pathExtension.lowercased())
    }
    var isAudioFile: Bool {
        ["mp3", "m4a", "wav", "aac", "flac"].contains(pathExtension.lowercased())
    }
}
```

### `Utilities/Constants.swift`
```swift
enum Constants {
    enum Directories {
        static let media = "Media"
    }
    enum Playback {
        static let skipInterval: TimeInterval = 15
        static let minPositionToSave: TimeInterval = 5
        static let speeds: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0]
    }
}
```

---

## Repeat Mode — Detailed Behavior

The repeat button in `PlayerControlsView` cycles through three states on each tap:

| State | Icon | Behavior |
|---|---|---|
| `.off` | `repeat` (gray) | Queue plays once; stops at last item |
| `.all` | `repeat` (accent color) | After last song, wraps back to first; infinite loop |
| `.one` | `repeat.1` (accent color) | Current song plays again from start when it ends; then still advances to next |

Implementation in `PlaybackService.handlePlaybackEnd()` (see above). The `.one` mode plays current song once more before advancing — matching Spotify's behavior exactly. Do not loop `.one` infinitely; only replay once and then advance.

---

## Documentation Files to Generate

### `README.md` — Required sections:
1. Short description of the app
2. Screenshot placeholder: `<!-- Screenshot here -->`
3. Requirements: Xcode 16+, iOS 17.0 target, physical iPhone for background audio
4. Clone & open: `git clone ... && open OfflineMediaLibrary.xcodeproj`
5. Signing: Team must be set in Xcode → Signing & Capabilities
6. Background audio: Must enable "Audio, AirPlay, and Picture in Picture" in Capabilities; test on real device only (simulator does not background audio)
7. File import: Use the Import tab, or drag files into the app's folder in the iOS Files app
8. Architecture: link to `ARCHITECTURE.md`
9. Roadmap: link to `ROADMAP.md`

### `ARCHITECTURE.md` — Required sections:
1. Layer diagram (Views → ViewModels → Services → Models)
2. SwiftData model graph with relationships
3. Playback flow: how a tap on AudioRowView reaches AVPlayer
4. Repeat mode state machine diagram
5. Extension points: how to add CloudKit sync, how to add URL import module, how to add lock screen controls (MPNowPlayingInfoCenter + MPRemoteCommandCenter)

### `CLAUDE.md` — Required sections:
1. Tech stack and iOS version rationale (iOS 17 = SwiftData, well-documented, iPhone 17 compatible)
2. Architecture rules: never bypass the Services layer from Views, always use modelContext from environment
3. SwiftData gotchas: don't pass ModelContext across threads; use @Query in views, not ViewModels
4. Repeat mode specification (off → all → one → off)
5. Where media files live on device: `Documents/Media/`
6. How to test background audio: must be on physical device; lock screen and verify playback continues
7. Git workflow: feature branches, PR to main via develop

### `ROADMAP.md` — Phase list:
- **Phase 2:** Lock screen / Control Center controls (`MPNowPlayingInfoCenter`, `MPRemoteCommandCenter`)
- **Phase 3:** Add Folders tab to main TabView (currently accessible from Settings)
- **Phase 4:** URL import module (HLS, direct MP3/MP4 URLs — lawful sources only)
- **Phase 5:** iCloud sync via CloudKit
- **Phase 6:** Home Screen / Lock Screen widgets
- **Phase 7:** AirPlay / external display
- **Phase 8:** macOS Catalyst port

### `.gitignore` — Must include:
```gitignore
# Xcode
*.xcuserdata/
*.xccheckout
DerivedData/
build/
*.pbxuser
*.perspectivev3
!default.pbxuser
!default.perspectivev3
xcuserdata/

# Swift Package Manager
.build/
.swiftpm/

# macOS
.DS_Store
*.swp

# Compiled binaries
*.ipa
*.dSYM.zip
*.dSYM

# Certificates
*.p12
*.mobileprovision
*.cer

# IDE
.idea/
*.xcworkspace/xcuserdata/
```

### `.github/workflows/ci.yml`
```yaml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: macos-15

    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -switch /Applications/Xcode_16.app/Contents/Developer

      - name: Build
        run: |
          xcodebuild build \
            -project OfflineMediaLibrary.xcodeproj \
            -scheme OfflineMediaLibrary \
            -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.0' \
            CODE_SIGNING_ALLOWED=NO \
            | xcpretty || xcodebuild build \
            -project OfflineMediaLibrary.xcodeproj \
            -scheme OfflineMediaLibrary \
            -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.0' \
            CODE_SIGNING_ALLOWED=NO
```

---

## Git Workflow

### Branch Strategy
```
main       — stable, tagged releases
develop    — integration branch (default PR target)
feature/*  — feature branches
fix/*      — bug fixes
```

### Recommended Commit Sequence (one feature branch per group)

| Branch | Commit message |
|---|---|
| `feature/project-bootstrap` | `chore: init Xcode project iOS 17, add gitignore` |
| `feature/docs` | `docs: add README, ARCHITECTURE, CLAUDE, ROADMAP` |
| `feature/models` | `feat: add SwiftData models (MediaItem, Playlist, Folder)` |
| `feature/services` | `feat: add FileImportService, MediaLibraryService` |
| `feature/playback` | `feat: add PlaybackService with background audio and repeat modes` |
| `feature/player-vm` | `feat: add PlayerViewModel bridging PlaybackService to UI` |
| `feature/tab-navigation` | `feat: add ContentView TabView with mini-player overlay` |
| `feature/audio-library` | `feat: add audio library with search and empty state` |
| `feature/video-library` | `feat: add video library with search and empty state` |
| `feature/full-player` | `feat: add full player screen with all controls and repeat button` |
| `feature/playlists` | `feat: add playlists with detail, reorder, and resume playback` |
| `feature/folders` | `feat: add folder/category organization` |
| `feature/import` | `feat: add import view with document picker and state handling` |
| `feature/url-placeholder` | `feat: add URL import placeholder screen` |
| `feature/ci` | `chore: add GitHub Actions CI workflow` |

Each branch is opened as a PR against `develop`, reviewed, and merged. `develop` is merged to `main` at milestones.

---

## Verification Checklist (Run on Physical iPhone 17)

### Build
- [ ] Project builds without errors or warnings with iOS 17.0 target
- [ ] No SwiftData migration errors on first launch
- [ ] 5 tabs visible in `ContentView`

### Import
- [ ] Document picker opens and shows Files app
- [ ] Importing an MP3 copies it to `Documents/Media/`
- [ ] File appears immediately in Audio library
- [ ] Importing an MP4 copies it to `Documents/Media/`
- [ ] File appears immediately in Video library
- [ ] Importing a duplicate-named file works (UUID prefix prevents collision)
- [ ] Error state shown if import fails

### Audio Playback
- [ ] Tapping an audio item starts playback
- [ ] Mini-player appears above tab bar
- [ ] Tapping mini-player opens full player
- [ ] Play/pause works
- [ ] Skip ±15 seconds works
- [ ] Previous track: within 3s → restart; after 3s → previous item
- [ ] Next track advances to next item in queue
- [ ] Progress slider scrubs position correctly
- [ ] Speed picker changes rate (0.75× through 2×)
- [ ] Shuffle button reorders queue
- [ ] **Repeat off:** playback stops after last track
- [ ] **Repeat all:** after last track, wraps to first and continues playing
- [ ] **Repeat one:** current track replays once from start, then advances to next
- [ ] **Repeat button cycles:** off → all → one → off on each tap
- [ ] Locking the screen does NOT stop audio (background audio works)
- [ ] Last played position is saved when app goes to background
- [ ] Reopening and playing the same item resumes from saved position

### Video Playback
- [ ] Tapping a video item opens the video player
- [ ] Video plays correctly

### Playlists
- [ ] Can create an audio playlist
- [ ] Can create a video playlist
- [ ] Can add items to a playlist from the library (long press / swipe action)
- [ ] Playlist detail shows items in correct order
- [ ] Can reorder items (drag handle)
- [ ] Can delete items from playlist (swipe)
- [ ] "Play" button in playlist plays from first item
- [ ] Resume: plays from `lastPlayedItemId` + `lastPlayedPosition`
- [ ] Repeat and shuffle work in playlist context

### Folders
- [ ] Can create a folder
- [ ] Can assign an item to a folder from the library
- [ ] Folder detail shows only items assigned to it

### Persistence
- [ ] Kill app (swipe from app switcher) and reopen — library intact
- [ ] Last position remembered per item
- [ ] Playlists survive restart
- [ ] Folders survive restart

### URL Import placeholder
- [ ] Placeholder screen is visible from Import tab
- [ ] Button is visible but disabled
- [ ] Explanatory text is shown

### Files app integration
- [ ] The app's `Documents/` folder is visible in Files
- [ ] Imported media files are visible in `Documents/Media/`

---

## Known iOS 17 SwiftData Considerations

- `@Query` only works inside `View` structs — do not use it in ViewModels
- Pass `modelContext` from views to service methods, never store it in services
- SwiftData `@Model` classes use reference semantics — handle carefully in concurrent contexts
- All SwiftData mutations must happen on the main actor; use `@MainActor` where needed
- `Relationship` inverse declarations: SwiftData auto-infers many-to-one from `@Model` class references, but explicitly declare inverse relationships in complex graphs to avoid migration issues
- If you add a property to a `@Model` after first launch, SwiftData handles lightweight migration automatically on iOS 17 — no migration plan needed for additive changes

---

## Final Instructions to Claude

1. Build files in this exact order: Models → Services → ViewModels → Views → Utilities → Docs
2. Every file must compile. No half-implementations left broken.
3. Use `ContentUnavailableView` for all empty states (iOS 17+).
4. Do not import any third-party packages. Zero external dependencies.
5. After generating all Swift files, generate all documentation files.
6. After documentation, generate `.gitignore` and `.github/workflows/ci.yml`.
7. End with a checklist of exactly what the user must manually do in Xcode (signing, background modes capability).
