# Scavodio — Audio Extractor

> Dig audio out of video files. Native macOS app, ffmpeg-powered.

Scavodio extracts audio tracks from video files (MKV, MP4, MOV, AVI, WebM and more) using ffmpeg under the hood. Drop a file, pick a track, pick a format — done.

![macOS](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5-orange)
![Architecture](https://img.shields.io/badge/arch-arm64-lightgrey)

---

## Features

- Drag & drop or file picker
- Auto-detects all audio tracks via ffprobe (shows language, codec, bitrate, title)
- Export formats: **MKA** (lossless copy), **MP3** (re-encode), **M4A** (AAC copy only)
- Built-in ffmpeg installer — click one button if ffmpeg is missing
- Live ffmpeg log output
- Show in Finder after extraction
- No sandbox, no Electron, no Python — pure SwiftUI

## Supported input formats

MKV · MP4 · MOV · AVI · WebM · M4V · MTS · M2TS · TS · FLV · WMV · VOB · 3GP

---

## Requirements

| | |
|---|---|
| macOS | 13.0 Ventura or later |
| Architecture | Apple Silicon (arm64) |
| Xcode | 15+ (to build from source) |
| ffmpeg | via Homebrew |

---

## Install ffmpeg

```bash
brew install ffmpeg
```

Or click **Install ffmpeg** button inside the app.

---

## Build

**Open in Xcode:**
```bash
open Scavodio.xcodeproj
```
Then press `⌘R`.

**Build from Terminal** (requires Xcode, not just CLT):
```bash
xcodebuild \
  -project Scavodio.xcodeproj \
  -scheme Scavodio \
  -configuration Debug \
  -arch arm64 \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  build
# → build/Build/Products/Debug/Scavodio.app
```

**Build without Xcode** (only CLT needed):
```bash
SDK=$(xcrun --sdk macosx --show-sdk-path)
mkdir -p build/Scavodio.app/Contents/MacOS
swiftc \
  -sdk "$SDK" -target arm64-apple-macosx13.0 \
  -parse-as-library -module-name Scavodio \
  -framework SwiftUI -framework AppKit \
  -framework Foundation -framework UniformTypeIdentifiers \
  Scavodio/AudioTrack.swift \
  Scavodio/SupportedFormats.swift \
  Scavodio/FFmpegService.swift \
  Scavodio/ContentView.swift \
  Scavodio/ScavodioApp.swift \
  -o build/Scavodio.app/Contents/MacOS/Scavodio
# then copy Info.plist and codesign
```

---

## Project structure

```
Scavodio/
├── ScavodioApp.swift        — @main entry point
├── ContentView.swift        — UI, drag & drop, file picker
├── AudioTrack.swift         — model
├── SupportedFormats.swift   — list of accepted video formats
├── FFmpegService.swift      — ffprobe probe + ffmpeg extract + brew install
├── Info.plist
└── Scavodio.entitlements
```

---

## Limitations

- Local use only, not for App Store distribution
- arm64 (Apple Silicon) only
- No video conversion — audio extraction only
- M4A export available only when source track is AAC
- Relies on installed ffmpeg/ffprobe
