<div align="center">

# Scavodio

**Extract audio from any video file. One click.**

[🇷🇺 Читать на русском](README.ru.md)

[![macOS](https://img.shields.io/badge/macOS-13%2B-black?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5-orange?logo=swift&logoColor=white)](https://swift.org)
[![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-arm64-blueviolet)](https://developer.apple.com/documentation/apple-silicon)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/tolcheev/Scavodio?color=brightgreen)](https://github.com/tolcheev/Scavodio/releases/latest)

[**Download DMG**](https://github.com/tolcheev/Scavodio/releases/latest) · [Report Bug](https://github.com/tolcheev/Scavodio/issues) · [Request Feature](https://github.com/tolcheev/Scavodio/issues)

</div>

---

Scavodio is a lightweight native macOS app that extracts audio tracks from video files using ffmpeg. Drop a file, pick a track, choose a format — done in seconds.

> *scavo* (Italian) — excavation. Dig the audio out.

---

## Features

- **Drag & drop** any video file onto the window, or use the file picker
- **Auto-detects all audio tracks** via ffprobe — shows codec, language, bitrate, and duration
- **7 export formats:** MP3 · MKA · AAC · M4A · OGG · FLAC · Opus
- **Split into parts** — cut long audio into chunks of 30 min · 1h · 2h · 3h · 4h · 6h. Preview shows the exact breakdown: `→ 3 parts: 3h + 3h + 1h`
- **Choose output folder** — save anywhere, not just next to the source file
- **One-click ffmpeg install** via Homebrew, with confirmation
- **Cancel** any extraction mid-way
- **Live log** — see exactly what ffmpeg is doing
- **⌘R** keyboard shortcut to start extraction
- No Electron. No Python. No subscriptions. Just Swift.

---

## Supported formats

| Video input | Audio output |
|---|---|
| MKV · MP4 · MOV · AVI · WebM · M4V | **MP3** · MKA · AAC · M4A · OGG · FLAC · Opus |
| MTS · M2TS · TS · FLV · WMV · VOB · 3GP | |

---

## Installation

### Option A — Download DMG (recommended)

1. Download from [**Releases**](https://github.com/tolcheev/Scavodio/releases/latest) and open the DMG
2. Drag **Scavodio** to **Applications**
3. Open the DMG's **"Open Privacy Settings"** shortcut, or go to:  
   **System Settings → Privacy & Security → Open Anyway**

Then install ffmpeg if you don't have it:

```bash
brew install ffmpeg
```

Or click **Install ffmpeg** inside the app.

> **Why the extra step?** Scavodio is ad-hoc signed, not notarized. macOS 13+ requires a one-time approval in System Settings for apps distributed outside the App Store. You only do this once.

### Option B — Build from source

**Requirements:** macOS 13+, Apple Silicon, Xcode Command Line Tools

```bash
xcode-select --install   # if not already installed

git clone https://github.com/tolcheev/Scavodio.git
cd Scavodio

./build.sh           # build to build/Scavodio.app
./build.sh install   # build + install to /Applications
```

The script compiles with `swiftc`, writes a correct `Info.plist`, copies the icon, and ad-hoc signs the bundle. No Xcode IDE required.

---

## How it works

```
Drop video / Choose file
        ↓
ffprobe → detect audio tracks (codec, language, bitrate, duration)
        ↓
Pick track + format + output folder
        ↓
ffmpeg → extract audio  [optionally split into parts]
        ↓
Output file(s) in chosen folder
```

Subprocess arguments are passed as arrays, never concatenated shell strings — **filenames with spaces, Unicode, and Cyrillic characters work fine**.

---

## Project structure

```
Scavodio/
├── ScavodioApp.swift        — @main entry point
├── ContentView.swift        — UI, drag & drop, error messages
├── AudioTrack.swift         — model (codec, language, bitrate, duration)
├── SupportedFormats.swift   — accepted video formats + UTType helpers
├── FFmpegService.swift      — ffprobe probe · ffmpeg extract · split · brew install
├── ProcessRunner.swift      — subprocess with 30s timeout
├── OutputFileNamer.swift    — safe filename builder, HFS+ compliant
├── SplitDuration.swift      — split chunk-size presets
├── AppIcon.icns             — app icon (included for source builds)
├── Info.plist
└── Scavodio.entitlements

ScavodioTests/
├── ProcessRunnerTests.swift
├── OutputFileNamerTests.swift
├── FFmpegServiceTests.swift
└── SizeBudgetTests.swift

build.sh                     — one-command build script (no Xcode needed)
dmg_background.swift         — DMG background image generator
```

---

## Requirements

| | |
|---|---|
| macOS | 13.0 Ventura or later |
| Architecture | Apple Silicon (arm64) |
| ffmpeg | via Homebrew (`brew install ffmpeg`) |
| To build | Xcode Command Line Tools (`xcode-select --install`) |

---

## Security

- No network access — everything runs locally
- No app sandbox (required to launch ffmpeg as subprocess)
- Hardened Runtime enabled
- Subprocess arguments are arrays — no shell injection possible

---

## Contributing

Pull requests are welcome. For major changes, open an issue first.

```bash
git clone https://github.com/tolcheev/Scavodio.git
cd Scavodio
open Scavodio.xcodeproj   # or: ./build.sh
```

Run tests: **⌘U** in Xcode.

---

## License

[MIT](LICENSE) — free to use, modify, and distribute.
