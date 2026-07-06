# Distributed-Social — Offline Media Library

A personal **offline media player** for iPhone — a Spotify-style app for *local files only*. Import MP3, M4A, WAV, MP4, and MOV files (individually, in bulk, or a whole folder as a playlist), organize them, and play them with a full-featured player. Once imported, the app works entirely offline.

> **Legal note:** This app only plays local files you import yourself. No downloading, no DRM circumvention, no platform-violating features.

<!-- Screenshot here -->

## Features

- **Import** — multi-select file import, or pick a folder (e.g. an unzipped playlist archive) to import every song in order and create a playlist named after it, with a progress bar. Embedded tags (title, artist, cover art) are read automatically; older imports are backfilled on launch.
- **Player** — full-screen player with carousel swipes (the neighboring song's card slides in), swipe-down to dismiss, scrubbing, shuffle, repeat (off → all → one, where *one* replays the song once), playback speed, ±15s skips, a favorite heart, AirPlay, and a sleep timer.
- **Mini player island** — floats above the tab bar, swipeable left/right with the same carousel transition.
- **Queue** — Spotify-style two-part queue: a manual FIFO ("In Queue") that always plays first, then the natural context ("Next Up"). Swipe a song left-to-right anywhere to queue it (confirmed by a toast); reorder or remove either section in the queue sheet.
- **Playlists** — two-column cover grid (custom photo, first song's album art, or a generated tile), marquee titles, per-playlist resume, in-playlist search, add-songs sheet, and total duration.
- **Home** — time-of-day greeting, Popular and Recently Played playlist carousels, six per-launch random Favorites with a Show More page, Most Played songs, Audio/Video library boxes, and app-wide search with "Play All" (a search result acts like a temporary playlist).
- **Lock screen / Control Center** — full Now Playing metadata with cover art and previous/play/next controls; background audio keeps playing with the screen locked.
- **Themes** — six persisted color themes (Spotify, Black & Orange, Black & Sky Blue, Sky Blue & Black, Sakura Pink, White & Green) that restyle the whole app.
- **Robustness** — files deleted from the Files app show greyed-out as unavailable (still deletable); playback skips missing files.

## Requirements

| | |
|---|---|
| Xcode | 16+ (built with the Xcode 26 toolchain) |
| Deployment target | iOS 18.0 |
| SDK | Latest installed iOS SDK (iOS 26) |
| Device | A physical iPhone is required to verify background audio (the simulator cannot background audio) |

## Clone & open

```sh
git clone https://github.com/philipfleischer/Distributed-Social
cd Distributed-Social
open Distributed-Social/Distributed-Social.xcodeproj
```

Set your **Team** in Signing & Capabilities. Bundle identifier: `com.philipfleischer.Distributed-Social`.

## File import

- **Settings → Import** → *Import Files* (multi-select) or *Import Folder as Playlist*, or
- Drag files into the app's folder in the iOS **Files** app (the app's `Documents/` folder is exposed). Imported media is copied to `Documents/Media/`.

For zipped playlists from a Mac: AirDrop the zip to the phone, tap it in Files to extract, then *Import Folder as Playlist*.

## Tests

Unit tests (Swift Testing) cover the queue logic, repeat state machine, library filtering, and formatting helpers. They live in `Distributed-SocialTests/` and run with ⌘U.

## Documentation

- Architecture: [ARCHITECTURE.md](ARCHITECTURE.md)
- Contributor / AI guide: [CLAUDE.md](CLAUDE.md)
- Roadmap: [ROADMAP.md](ROADMAP.md)
