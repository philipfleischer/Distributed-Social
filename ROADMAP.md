# Roadmap

## Shipped

- ✅ Core player: import, libraries, playlists, folders*, full playback controls, background audio
- ✅ Lock screen / Control Center controls (`MPNowPlayingInfoCenter` + `MPRemoteCommandCenter`) with cover art
- ✅ Spotify-style two-part queue (manual FIFO + context) with swipe-to-queue and toasts
- ✅ Six persisted color themes
- ✅ Embedded tag metadata (title/artist/cover art) + launch backfill for old imports
- ✅ Carousel swipe transitions (mini island + full player), haptics
- ✅ Favorites (per-launch random picks + full list), Most Played stats
- ✅ Sleep timer, AirPlay, playlist resume, in-playlist search & add-songs
- ✅ Missing-file detection (greyed rows, playback skip)
- ✅ Unit tests (Swift Testing) for queue, repeat, filtering, and formatting

\* Folders were later removed from the UI as unused; the model remains in the schema for migration safety.

## Planned

- **URL import module:** lawful direct MP3/MP4 URLs and HLS (behind a future Import option).
- **iCloud sync:** CloudKit-backed SwiftData container.
- **Widgets:** Home Screen / Lock Screen widgets (Recently Played, Favorites).
- **macOS Catalyst port.**
