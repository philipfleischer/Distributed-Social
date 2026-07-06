# Architecture

The app follows **MVVM + a Services layer** (light Clean Architecture). Dependencies point inward: Views depend on ViewModels and Services; Services depend on Models; Models depend on nothing.

## Layers

```
Views  ─────▶  ViewModels  ─────▶  Services  ─────▶  Models (SwiftData)
  │                                    │
  └──────────  @Query / ModelContext (SwiftData) ──────────┘
```

- **Views** (SwiftUI) own their data via `@Query` and read the environment `ModelContext`. Cross-cutting mutations go through the Services.
- **ViewModels** (`ObservableObject`) hold view state. `PlayerViewModel` bridges `PlaybackService` to the UI via Combine `assign(to:)` and adds UI-level concerns (queue toasts, haptics).
- **Services** — `PlaybackService` (AVPlayer, queues, repeat/shuffle, sleep timer, Now Playing), `FileImportService` (copy/delete files, tag extraction, folder import, metadata backfill), `MediaLibraryService` (SwiftData mutations).
- **Models** are SwiftData `@Model` classes; the theme system (`AppTheme`/`ThemeStore`) persists via UserDefaults.

## SwiftData model graph

```
MediaItem >──< PlaylistItem >── Playlist
```

| Model | Notes |
|---|---|
| `MediaItem` | title/artist/artwork from embedded tags, duration, `lastPosition` (resume), `isFavorite`, `playCount`; `isFileMissing` derived at runtime |
| `Playlist` | `imageData` (custom cover, external storage), `lastPlayedItemId`/`lastPlayedDate`/`playCount` (resume + Home carousels) |
| `PlaylistItem` | join row with `sortOrder` |
| `Folder` | **dormant** — feature removed from the UI; kept in the schema so existing stores migrate cleanly |

**Key decision:** `MediaItem` persists only a relative `filename`; the absolute `localURL` is derived at runtime from `Documents/Media/`. This keeps the library valid across reinstalls.

## Playback queue model (Spotify-style)

```
             ┌──────────────────┐   drained    ┌───────────────────────┐
 nextTrack ─▶│ manualQueue FIFO │─────────────▶│ contextQueue[idx + 1…]│
             │   ("In Queue")   │              │      ("Next Up")      │
             └──────────────────┘              └───────────────────────┘
```

- `contextQueue` + `currentIndex` = the natural play order (library/playlist).
- `manualQueue` = user-queued songs; always plays first, **without moving** `currentIndex`, so the context resumes exactly where it would have.
- *Play Next* inserts at the front of the manual queue; *Add to Queue* appends.
- Shuffle reshuffles the context only; repeat-all wraps the context only.
- `peekNext`/`peekPrevious` expose what a swipe would play — they drive the carousel previews in the mini island and full player.

## Repeat mode state machine

```
        tap            tap            tap
 .off ───────▶ .all ───────▶ .one ───────▶ .off
```

`.one` replays the current track exactly once (reloading it through the normal track-load path — seeking the ended AVPlayerItem is unreliable), then advances.

## Playback flow

```
Row tap → PlayerViewModel.play(item:in:) → PlaybackService.play
        → loadMedia: reset time state, AVPlayer.replaceCurrentItem, play
        → periodic observer reads the *live* player position (stale-callback safe)
        → @Published state → PlayerViewModel → UI + MPNowPlayingInfoCenter
```

Missing files are skipped automatically (bounded so an all-missing queue cannot loop).

## Theme system

`AppTheme` (enum) defines background gradient, text colors, highlight color, chip fill, and light/dark chrome per theme; `ThemeStore` publishes the selection and persists it. Views apply `.summerBackground()` and read `theme.textPrimary`/`textSecondary`.

## Extension points

- **URL import:** feed lawful direct-URL downloads into `FileImportService`.
- **CloudKit sync:** swap the `modelContainer` for a CloudKit-backed configuration.
- **Widgets:** surface Recently Played / Favorites via a widget extension reading the shared store.
