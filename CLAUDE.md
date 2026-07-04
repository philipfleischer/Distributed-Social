# CLAUDE.md — Project guide

## Tech stack

- **SwiftUI** UI, **SwiftData** persistence, **AVFoundation/AVKit** playback.
- **Deployment target: iOS 18.0**, built against the latest iOS SDK (iOS 26) so it runs on the newest devices (e.g. iPhone 17) while keeping a stable API surface.
- No third-party dependencies.

## Architecture rules

- Never bypass the Services layer from Views for cross-cutting mutations — go through `MediaLibraryService` / `FileImportService` / `PlaybackService`.
- Always use the `ModelContext` from the SwiftUI environment; never store a `ModelContext` inside a service.
- Use `@Query` in Views only — never in ViewModels.

## SwiftData gotchas

- `@Model` classes use reference semantics; mutate them on the main actor (the project uses default `MainActor` isolation).
- Don't pass a `ModelContext` across threads.
- Additive model changes migrate automatically (lightweight migration) on iOS 17+.
- Persisted `@Model` stored properties have default values so the schema is unambiguous.

## Repeat mode specification

`off → all → one → off` on each tap. `.one` replays the current track once, then advances (it does not loop forever). See `RepeatMode` and `PlaybackService.handlePlaybackEnd()`.

## Where files live

Imported media is copied to `Documents/Media/<UUID>-<originalName>`. Only the relative filename is stored in SwiftData; `MediaItem.localURL` derives the absolute path at runtime.

## Testing background audio

Must be done on a **physical device**. Play audio, lock the screen, confirm playback continues. The simulator cannot background audio.

## Color theme

Summery Japanese palette defined in `Utilities/Theme.swift`: `Color.skyBlue`, `Color.sakuraPink`, `Color.softWhite`, plus the `summerBackground()` modifier. The asset-catalog `AccentColor` is set to sky blue.

## Git workflow

`main` (stable) ← `develop` (integration) ← `feature/*` / `fix/*`. Open PRs against `develop`; merge `develop` to `main` at milestones.
