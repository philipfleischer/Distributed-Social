# CLAUDE.md — Project guide

## Tech stack

- **SwiftUI** UI, **SwiftData** persistence, **AVFoundation/AVKit** playback, **MediaPlayer** for lock-screen controls.
- **Deployment target: iOS 18.0**, built against the latest iOS SDK (iOS 26) so it runs on the newest devices (e.g. iPhone 17).
- No third-party dependencies.

## App structure

Three tabs: **Home** (greeting, Popular/Recently Played playlists, Favorites, Most Played, library boxes, global search), **Playlists** (cover grid), **Settings** (theme picker, import, About). The full player is an **overlay** above the TabView (not a sheet); the mini player island floats above the tab bar.

## Architecture rules

- Never bypass the Services layer from Views for cross-cutting mutations — go through `MediaLibraryService` / `FileImportService` / `PlaybackService`.
- Always use the `ModelContext` from the SwiftUI environment; never store a `ModelContext` inside a service.
- Use `@Query` in Views only — never in ViewModels.
- Services must not import SwiftUI.

## SwiftData gotchas

- `@Model` classes use reference semantics; mutate them on the main actor (the project uses default `MainActor` isolation).
- Don't pass a `ModelContext` across threads.
- Additive model changes migrate automatically (lightweight migration); avoid removing models/properties — the dormant `Folder` model stays in the schema for exactly this reason.
- Persisted `@Model` stored properties have default values so the schema is unambiguous.

## Queue model

Two-part, Spotify-style (see `PlaybackService`): `manualQueue` (user FIFO, always plays first, does **not** move `currentIndex`) and `contextQueue`+`currentIndex` (natural order). `peekNext`/`peekPrevious` drive the swipe-carousel previews and must stay consistent with `nextTrack()`/`forcePreviousTrack()`.

## Repeat mode specification

`off → all → one → off` on each tap. `.one` replays the current track once, then advances. The replay must go through `loadMedia` (reload from scratch) — seeking the ended `AVPlayerItem` and calling `play()` silently fails.

## Playback pitfalls (learned the hard way)

- The periodic time observer must read `player.currentTime()` live, not the callback's time argument (stale queued callbacks otherwise overwrite the reset scrubber on track change).
- Lock screen: enabling `skipForward/BackwardCommand` **replaces** next/previous track buttons — keep skip commands disabled.
- Missing files (`MediaItem.isFileMissing`) are skipped by `loadMedia` with a bounded counter; UI shows them greyed and only deletable.

## Where files live

Imported media is copied to `Documents/Media/<UUID>-<originalName>`. Only the relative filename is stored in SwiftData; `MediaItem.localURL` derives the absolute path at runtime. Embedded tags (title/artist/artwork) are read at import; `backfillMetadataIfNeeded` upgrades pre-tag imports once (UserDefaults flag).

## Themes

`AppTheme` + `ThemeStore` in `Utilities/Theme.swift`; six themes persisted via UserDefaults. Views read `theme.textPrimary`/`textSecondary` and apply `.summerBackground()`. New UI must be themed — no hard-coded text colors.

## Testing

- Unit tests use the **Swift Testing** framework in `Distributed-SocialTests/` (queue logic, repeat state machine, filtering, formatting). Queue tests create real empty files under `Documents/Media` so the missing-file guard doesn't skip them.
- Background audio must be verified on a **physical device**: play audio, lock the screen, confirm playback continues.

## Git workflow

`main` (stable) ← `develop` (integration) ← `feature/*` / `fix/*`. Open PRs against `develop`; merge `develop` to `main` at milestones. CI builds with the generic iOS Simulator destination (named simulators are flaky on runners).
