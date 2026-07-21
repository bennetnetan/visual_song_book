#!/usr/bin/env bash
set -e

APP_DIR="build/AppDir"
BUNDLE_DIR="build/linux/x64/release/bundle"
OUTPUT_APPIMAGE="build/Visual_Song_Book-1.5.0-x86_64.AppImage"

if [ ! -d "$BUNDLE_DIR" ]; then
  echo "Error: $BUNDLE_DIR does not exist. Run 'flutter build linux --release' first."
  exit 1
fi

# Ensure appimagetool is downloaded
if [ ! -f "build/appimagetool" ]; then
  echo "Downloading appimagetool..."
  mkdir -p build
  curl -sL "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage" -o build/appimagetool
  chmod +x build/appimagetool
fi

echo "Setting up AppDir structure..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR"

# Copy Flutter release bundle contents into AppDir root
cp -r "$BUNDLE_DIR"/* "$APP_DIR/"

# Copy icon
cp "assets/images/logo.png" "$APP_DIR/visual_song_book.png"
cp "assets/images/logo.png" "$APP_DIR/.DirIcon"

# Create .desktop file
cat << 'EOF' > "$APP_DIR/visual_song_book.desktop"
[Desktop Entry]
Name=Visual Song Book
Comment=Visual Song Book — Church Hymnal & Live Projection App
Exec=visual_song_book
Icon=visual_song_book
Terminal=false
Type=Application
Categories=Utility;AudioVideo;Presentation;
EOF

# Create AppRun script
cat << 'EOF' > "$APP_DIR/AppRun"
#!/bin/bash
HERE="$(dirname "$(readlink -f "${0}")")"
export PATH="${HERE}:${PATH}"
export LD_LIBRARY_PATH="${HERE}/lib:${LD_LIBRARY_PATH}"
exec "${HERE}/visual_song_book" "$@"
EOF
chmod +x "$APP_DIR/AppRun"

echo "Building AppImage..."
ARCH=x86_64 ./build/appimagetool --no-appstream "$APP_DIR" "$OUTPUT_APPIMAGE"

echo "AppImage created successfully at: $OUTPUT_APPIMAGE"
