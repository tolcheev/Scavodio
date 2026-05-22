<div align="center">

# Scavodio

**Extract audio from any video file. One click.**

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
- **Auto-detects all audio tracks** via ffprobe — shows codec, language, bitrate, and title
- **7 export formats:** MP3 · MKA · AAC · M4A · OGG · FLAC · Opus
- **One-click ffmpeg install** if it's missing (via Homebrew, with confirmation)
- **Cancel** any extraction mid-way
- **Live log** — see exactly what ffmpeg is doing
- **Show in Finder** after extraction completes
- **⌘R** keyboard shortcut to start extraction
- No Electron. No Python. No subscriptions. Just Swift.

---

## Supported formats

| Video input | Audio output |
|---|---|
| MKV · MP4 · MOV · AVI · WebM · M4V | **MP3** · MKA (copy) · AAC · M4A · OGG · FLAC · Opus |
| MTS · M2TS · TS · FLV · WMV · VOB · 3GP | |

---

## Installation

### Option A — Download DMG (recommended)

1. Go to [**Releases**](https://github.com/tolcheev/Scavodio/releases/latest)
2. Download the DMG, open it, drag **Scavodio** to Applications
3. On first launch run once in Terminal:

```bash
xattr -cr /Applications/Scavodio.app
```

> This removes the macOS quarantine flag that Gatekeeper sets on internet downloads.
> Without it, macOS shows a "damaged" error for ad-hoc signed apps.
> You only need to do this once.

Then install ffmpeg if you don't have it:

```bash
brew install ffmpeg
```

Or just click **Install ffmpeg** inside the app — it will do it for you.

### Option B — Build from source

**Requirements:** macOS 13+, Apple Silicon, Xcode Command Line Tools

```bash
# Install Command Line Tools if needed
xcode-select --install

git clone https://github.com/tolcheev/Scavodio.git
cd Scavodio

# Build
./build.sh

# Build + install to /Applications (also removes quarantine flag)
./build.sh install
```

That's it. The script compiles with `swiftc`, writes a correct `Info.plist`, copies the icon, and ad-hoc signs the bundle. No Xcode required.

To open in Xcode instead:

```bash
open Scavodio.xcodeproj
```

---

## How it works

```
┌─────────────────────────────────────┐
│  Drop video / Choose file           │
│         ↓                           │
│  ffprobe → detect audio tracks      │
│         ↓                           │
│  Pick track + format                │
│         ↓                           │
│  ffmpeg → extract audio             │
│         ↓                           │
│  Output file next to source         │
└─────────────────────────────────────┘
```

ffmpeg and ffprobe are called as subprocesses via `Process.arguments[]` — never as shell strings, so **filenames with spaces, Unicode, and Cyrillic characters work fine**.

---

## Project structure

```
Scavodio/
├── ScavodioApp.swift        — @main entry point
├── ContentView.swift        — UI, drag & drop, file picker, error messages
├── AudioTrack.swift         — model
├── SupportedFormats.swift   — accepted video formats + UTType helpers
├── FFmpegService.swift      — ffprobe probe · ffmpeg extract · brew install
├── ProcessRunner.swift      — subprocess with 30s timeout (no infinite hangs)
├── OutputFileNamer.swift    — safe filename builder, HFS+ compliant
├── AppIcon.icns             — app icon (included for source builds)
├── Info.plist               — bundle metadata template
└── Scavodio.entitlements

ScavodioTests/
├── ProcessRunnerTests.swift     — timeout, args, launch failure
├── OutputFileNamerTests.swift   — path traversal, null bytes, 255-byte limit
├── FFmpegServiceTests.swift     — binary detection, JSON parsing, cancel, security
└── SizeBudgetTests.swift        — binary/bundle size regression tests

build.sh                     — one-command build script (no Xcode needed)
```

---

## Requirements

| | |
|---|---|
| macOS | 13.0 Ventura or later |
| Architecture | Apple Silicon (arm64) |
| ffmpeg | via Homebrew (`brew install ffmpeg`) |
| Xcode | Command Line Tools only (`xcode-select --install`) |

---

## Security

- No network access — everything runs locally
- No app sandbox (required to launch ffmpeg as subprocess)
- Ad-hoc signed — remove quarantine with `xattr -cr` on first install (see above)
- Hardened Runtime enabled
- Subprocess arguments are passed as arrays, never concatenated shell strings

---

## Contributing

Pull requests are welcome. For major changes, open an issue first.

```bash
git clone https://github.com/tolcheev/Scavodio.git
cd Scavodio
open Scavodio.xcodeproj   # or build with ./build.sh
```

Run tests: `⌘U` in Xcode.

---

## License

[MIT](LICENSE) — free to use, modify, and distribute.
