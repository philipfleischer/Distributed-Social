# Architecture

The app follows **MVVM + a Services layer** (light Clean Architecture). Dependencies point inward: Views depend on ViewModels and Services; Services depend on Models; Models depend on nothing.

## Layers

```
Views  ─────▶  ViewModels  ─────▶  Services  ─────▶  Models (SwiftData)
  │                                    │
  └──────────  @Query / ModelContext (SwiftData) ──────────┘
```

- **Views** (SwiftUI) own their data via `@Query` and read the environment `ModelContext`. They never talk to the persistence store except through `@Query` and the Services.
- **ViewModels** (`ObservableObject`) hold view state and presentation logic. `PlayerViewModel` bridges `PlaybackService` to the UI via Combine `assign(to:)`.
- **Services** encapsulate cross-cutting work: `PlaybackService` (AVPlayer + queue), `FileImportService` (copy/delete files), `MediaLibraryService` (SwiftData mutations).
- **Models** are SwiftData `@Model` classes.

## SwiftData model graph

```
Folder 1 ──< MediaItem >── ? folder
                 │
                 └──< PlaylistItem >── Playlist
```

| Model | Key relationships |
|---|---|
| `MediaItem` | `folder: Folder?`, `playlistItems: [PlaylistItem]?` |
| `Folder` | `items: [MediaItem]?` (inverse of `MediaItem.folder`) |
| `Playlist` | `orderedItems: [PlaylistItem]?` (inverse of `PlaylistItem.playlist`) |
| `PlaylistItem` | `mediaItem: MediaItem?`, `playlist: Playlist?`, `sortOrder: Int` |

**Key decision:** `MediaItem` persists only a relative `filename`; the absolute `localURL` is derived at runtime from `Documents/Media/`. This keeps the library valid across reinstalls and OS updates where the sandbox path changes.

## Playback flow

```
AudioRowView tap
      │ onPlay()
      ▼
PlayerViewModel.play(item:in:)        ← startAt = item.lastPosition (resume)
      │
      ▼
PlaybackService.play(item:in:startAt:)
      │ builds activeQueue (shuffled or not), picks index
      ▼
loadItem(at:) → AVPlayer.replaceCurrentItem → play()
      │
      ▼
periodic time observer → @Published currentTime → PlayerViewModel → UI
```

## Repeat mode state machine

```
        tap            tap            tap
 .off ───────▶ .all ───────▶ .one ───────▶ .off
```

| State | Behavior at end of track |
|---|---|
| `.off` | Advance; stop after the last item |
| `.all` | Advance; wrap from last back to first (infinite) |
| `.one` | Replay current track once from start, then advance |

Implemented in `PlaybackService.handlePlaybackEnd()`.

## Extension points

- **Lock screen / Control Center controls:** add `MPNowPlayingInfoCenter` + `MPRemoteCommandCenter` wiring inside `PlaybackService`.
- **URL import:** implement behind the disabled placeholder in `ImportView`, feeding downloaded files into `FileImportService`.
- **CloudKit sync:** swap the `modelContainer` for a CloudKit-backed configuration; the relative-path file design already supports per-device file resolution.
