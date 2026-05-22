#!/usr/bin/env bash
# build.sh — builds Scavodio.app without Xcode (only Command Line Tools required)
#
# Usage:
#   ./build.sh          — build to build/Scavodio.app
#   ./build.sh install  — build and copy to /Applications
#
# Requirements: macOS 13+, Apple Silicon, Xcode Command Line Tools
#   xcode-select --install

set -euo pipefail

VERSION="1.2"
BUNDLE_ID="com.tolcheev.Scavodio"
ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/build/Scavodio.app"
SDK=$(xcrun --sdk macosx --show-sdk-path)

# Build number = total git commits (or 1 if git unavailable)
BUILD=$(git -C "$ROOT" rev-list --count HEAD 2>/dev/null || echo 1)

echo "► Scavodio $VERSION (build $BUILD)"

# ── 1. Bundle structure ────────────────────────────────────────────────────
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

# ── 2. Compile ─────────────────────────────────────────────────────────────
echo "► Compiling…"
swiftc \
  -sdk "$SDK" \
  -target arm64-apple-macosx13.0 \
  -parse-as-library \
  -module-name Scavodio \
  -Osize \
  -whole-module-optimization \
  -Xlinker -S \
  -Xlinker -dead_strip \
  -framework SwiftUI \
  -framework AppKit \
  -framework Foundation \
  -framework UniformTypeIdentifiers \
  "$ROOT"/Scavodio/*.swift \
  -o "$APP/Contents/MacOS/Scavodio"

SIZE=$(du -sh "$APP/Contents/MacOS/Scavodio" | cut -f1)
echo "  Binary: $SIZE"

# ── 3. Info.plist (variables fully substituted — no Xcode required) ────────
cat > "$APP/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>               <string>Scavodio</string>
    <key>CFBundleIdentifier</key>               <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>    <string>6.0</string>
    <key>CFBundleName</key>                     <string>Scavodio</string>
    <key>CFBundleDisplayName</key>              <string>Scavodio</string>
    <key>CFBundlePackageType</key>              <string>APPL</string>
    <key>CFBundleShortVersionString</key>       <string>$VERSION</string>
    <key>CFBundleVersion</key>                  <string>$BUILD</string>
    <key>CFBundleIconFile</key>                 <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>           <string>13.0</string>
    <key>NSHighResolutionCapable</key>          <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key> <true/>
    <key>NSPrincipalClass</key>                 <string>NSApplication</string>
</dict>
</plist>
PLIST

# ── 4. App icon ────────────────────────────────────────────────────────────
if [[ -f "$ROOT/Scavodio/AppIcon.icns" ]]; then
    cp "$ROOT/Scavodio/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
else
    echo "  ⚠  AppIcon.icns not found — app will launch without an icon"
fi

# ── 5. Ad-hoc codesign (Hardened Runtime) ─────────────────────────────────
echo "► Signing…"
codesign \
  --sign - \
  --options runtime \
  --entitlements "$ROOT/Scavodio/Scavodio.entitlements" \
  "$APP"

echo ""
echo "✓  Built:  $APP"
echo ""

# ── 6. Optional install ────────────────────────────────────────────────────
if [[ "${1:-}" == "install" ]]; then
    echo "► Installing to /Applications…"
    rm -rf /Applications/Scavodio.app
    cp -R "$APP" /Applications/Scavodio.app
    # Remove quarantine flag so Gatekeeper doesn't block the app
    xattr -cr /Applications/Scavodio.app
    echo "✓  Installed. Open Scavodio from /Applications."
else
    echo "   To install:  ./build.sh install"
    echo "   Or drag $APP to /Applications,"
    echo "   then run:    xattr -cr /Applications/Scavodio.app"
fi
