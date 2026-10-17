#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash Scripts/build-icon.sh
swift build -c release
BIN="$(swift build -c release --show-bin-path)"
APP="$PWD/dist/Memora.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/Memora" "$APP/Contents/MacOS/Memora"
cp .build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp -R "$BIN/Memora_Memora.bundle" "$APP/Contents/Resources/"
# SwiftPM's generated resource locator also checks alongside the executable.
cp -R "$BIN/Memora_Memora.bundle" "$APP/Contents/MacOS/"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Memora</string>
<key>CFBundleIdentifier</key><string>local.metaimage.editor</string>
<key>CFBundleName</key><string>Memora</string>
<key>CFBundleDisplayName</key><string>Memora</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>CFBundleDocumentTypes</key><array><dict><key>CFBundleTypeName</key><string>Image</string><key>CFBundleTypeRole</key><string>Viewer</string><key>LSItemContentTypes</key><array><string>public.image</string></array></dict></array>
</dict></plist>
PLIST
codesign --force --deep --sign - "$APP"
echo "$APP"
