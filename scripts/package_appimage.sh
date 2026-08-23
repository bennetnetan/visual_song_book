#!/usr/bin/env bash
set -euo pipefail

APP_DIR="build/AppDir"
BUNDLE_DIR="build/linux/x64/release/bundle"

# Read current version from pubspec.yaml
APP_VERSION=$(grep '^version: ' pubspec.yaml | sed 's/version: //' | cut -d+ -f1)
OUTPUT_APPIMAGE="build/Visual_Song_Book-${APP_VERSION}-x86_64.AppImage"

# Flutter binary: honor FLUTTER_BIN override, else fall back to PATH.
FLUTTER="${FLUTTER_BIN:-$(command -v flutter || true)}"
if [ -z "$FLUTTER" ]; then
  echo "Error: Flutter not found. Install Flutter or set FLUTTER_BIN." >&2
  exit 1
fi

if [ ! -d "$BUNDLE_DIR" ]; then
  echo "Error: $BUNDLE_DIR does not exist. Run 'flutter build linux --release' first." >&2
  exit 1
fi

# Ensure appimagetool is downloaded
if [ ! -f "build/appimagetool" ]; then
  echo "Downloading appimagetool..."
  mkdir -p build
  if command -v wget &>/dev/null; then
    wget -q --show-progress \
      "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage" \
      -O build/appimagetool
  else
    curl -sL "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage" \
      -o build/appimagetool
  fi
  chmod +x build/appimagetool
fi

echo "Setting up AppDir structure..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR"

# Copy Flutter release bundle contents into AppDir root
cp -r "$BUNDLE_DIR"/* "$APP_DIR/"

# --- Icons (multiple resolutions for OS integration) ---
ICON_BASE="$APP_DIR/usr/share/icons/hicolor"
for size in 48 64 96 128 256; do
  install -Dm644 assets/images/logo.png "${ICON_BASE}/${size}x${size}/apps/visual_song_book.png"
done
install -Dm644 assets/images/logo.png "${ICON_BASE}/scalable/apps/visual_song_book.png"

# Root-level icon for appimagetool discovery
cp assets/images/logo.png "$APP_DIR/visual_song_book.png"
cp assets/images/logo.png "$APP_DIR/.DirIcon"

# --- .desktop file ---
cat << EOF > "$APP_DIR/visual_song_book.desktop"
[Desktop Entry]
Name=Visual Song Book
Comment=Visual Song Book — Church Hymnal & Live Projection App
Exec=visual_song_book
Icon=visual_song_book
Terminal=false
Type=Application
Categories=Utility;AudioVideo;Presentation;
StartupWMClass=com.example.visual_song_book
EOF

# --- AppRun script ---
cat << 'EOF' > "$APP_DIR/AppRun"
#!/bin/bash
HERE="$(dirname "$(readlink -f "${0}")")"
export PATH="${HERE}:${PATH}"
export LD_LIBRARY_PATH="${HERE}/lib:${LD_LIBRARY_PATH}"
exec "${HERE}/visual_song_book" "$@"
EOF
chmod +x "$APP_DIR/AppRun"

echo "Building AppImage..."
# appimagetool requires FUSE; fall back to --appimage-extract-and-run when unavailable.
EXTRA_ARGS=""
if ! fusermount --version &>/dev/null 2>&1; then
  EXTRA_ARGS="--appimage-extract-and-run"
  echo "Warning: FUSE not available — using --appimage-extract-and-run fallback"
fi

ARCH=x86_64 ./build/appimagetool $EXTRA_ARGS --no-appstream "$APP_DIR" "$OUTPUT_APPIMAGE"

echo "AppImage created successfully at: $OUTPUT_APPIMAGE"
