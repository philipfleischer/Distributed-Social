# Distributed-Social — Offline Media Library

A personal **offline media library** for iPhone — a lightweight Spotify/YouTube hybrid for *local files only*. Import MP3, M4A, WAV, MP4, and MOV files from the iOS Files app, organize them into folders and playlists, and play them with full transport controls. Once imported, the app works entirely offline.

> **Legal note:** This app only plays local files you import yourself. There is no YouTube downloading, no DRM circumvention, and no platform-violating features. The "URL Import" screen is a disabled placeholder reserved for future lawful use.

<!-- Screenshot here -->

## Theme

A summery Japanese palette — soft white, sky blue, and sakura pink.

## Requirements

| | |
|---|---|
| Xcode | 16+ (built with Xcode 26 toolchain) |
| Deployment target | iOS 18.0 |
| SDK | Latest installed iOS SDK (iOS 26) |
| Device | A physical iPhone is required to verify background audio (the simulator does not background audio) |

## Clone & open

```sh
git clone https://github.com/philipfleischer/Distributed-Social
cd Distributed-Social
open Distributed-Social/Distributed-Social.xcodeproj
```

## Signing

In Xcode → **Signing & Capabilities**, set your **Team**. The bundle identifier is `com.philipfleischer.Distributed-Social`.

## Background audio

The target declares the `audio` background mode and sets the audio session category to `.playback`, so playback continues when the screen is locked. **This only works on a real device** — verify by playing audio and locking the phone.

## File import

- Use the **Import** tab → *Choose from Files*, or
- Drag files into the app's folder in the iOS **Files** app (the app's `Documents/` folder is exposed). Imported media is copied to `Documents/Media/`.

## Documentation

- Architecture: [ARCHITECTURE.md](ARCHITECTURE.md)
- Contributor / AI guide: [CLAUDE.md](CLAUDE.md)
- Roadmap: [ROADMAP.md](ROADMAP.md)
