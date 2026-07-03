#!/bin/bash
# =============================================================================
# Visual Song Book — Linux AppImage Builder
# =============================================================================
# Usage:
#   ./build_appimage.sh              # Build release AppImage
#   ./build_appimage.sh --skip-build # Repackage only (reuse existing bundle)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
APP_NAME="VisualSongBook"
BINARY_NAME="visual_song_book"
VERSION=$(grep '^version:' "$PROJECT_DIR/pubspec.yaml" | sed 's/version: *//;s/+.*//' | tr -d '[:space:]')
ARCH="x86_64"

FLUTTER="${FLUTTER_BIN:-/home/benjanetan/Code/flutter/bin/flutter}"
APPIMAGE_TOOL="$PROJECT_DIR/tools/appimagetool-x86_64.AppImage"
APPDIR="$PROJECT_DIR/build/appimage/${APP_NAME}.AppDir"
BUNDLE_DIR="$PROJECT_DIR/build/linux/x64/release/bundle"
OUTPUT_APPIMAGE="$PROJECT_DIR/${APP_NAME}-${VERSION}-${ARCH}.AppImage"

# ─── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ─── Check Flutter ────────────────────────────────────────────────────────────
check_flutter() {
  if [ ! -x "$FLUTTER" ]; then
    # Try finding flutter in PATH
    if command -v flutter &>/dev/null; then
      FLUTTER=$(command -v flutter)
    else
      error "Flutter not found. Set FLUTTER_BIN env var or install Flutter."
    fi
  fi
  info "Flutter: $FLUTTER"
  info "Version: $($FLUTTER --version 2>/dev/null | head -1)"
}

# ─── Download appimagetool if missing ─────────────────────────────────────────
ensure_appimagetool() {
  if [ -x "$APPIMAGE_TOOL" ]; then
    info "appimagetool found: $APPIMAGE_TOOL"
    return
  fi

  warn "appimagetool not found — downloading..."
  mkdir -p "$(dirname "$APPIMAGE_TOOL")"
  local url="https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
  
  if command -v wget &>/dev/null; then
    wget -q --show-progress -O "$APPIMAGE_TOOL" "$url"
  elif command -v curl &>/dev/null; then
    curl -L --progress-bar -o "$APPIMAGE_TOOL" "$url"
  else
    error "Neither wget nor curl found. Please install one."
  fi

  chmod +x "$APPIMAGE_TOOL"
  success "appimagetool downloaded to $APPIMAGE_TOOL"
}

# ─── Build Flutter release bundle ─────────────────────────────────────────────
build_flutter() {
  info "Building Flutter Linux release (v${VERSION})..."
  cd "$PROJECT_DIR"
  "$FLUTTER" build linux --release
  success "Flutter build complete → $BUNDLE_DIR"
}

# ─── Assemble AppDir ──────────────────────────────────────────────────────────
assemble_appdir() {
  info "Assembling AppDir at $APPDIR..."

  rm -rf "$APPDIR"
  # Flutter resolves lib/libapp.so relative to the binary's own directory.
  # The binary MUST live in usr/ directly (NOT usr/bin/) so usr/lib/ is found.
  mkdir -p "$APPDIR/usr/"{lib,data,share/icons/hicolor/256x256/apps,share/applications}

  # ── Copy Flutter bundle ──
  if [ ! -d "$BUNDLE_DIR" ]; then
    error "Flutter bundle not found at $BUNDLE_DIR. Run without --skip-build first."
  fi

  # Main binary → usr/  (must be adjacent to lib/ and data/)
  cp "$BUNDLE_DIR/$BINARY_NAME" "$APPDIR/usr/$BINARY_NAME"
  chmod +x "$APPDIR/usr/$BINARY_NAME"

  # Shared libraries → usr/lib/  (libapp.so, libflutter_linux_gtk.so, etc.)
  if [ -d "$BUNDLE_DIR/lib" ]; then
    cp -r "$BUNDLE_DIR/lib/." "$APPDIR/usr/lib/"
  else
    error "lib/ directory missing from bundle — release build may have failed."
  fi

  # Verify libapp.so (the AOT-compiled Dart code) is present
  if [ ! -f "$APPDIR/usr/lib/libapp.so" ]; then
    error "libapp.so not found — was this actually a --release build?"
  fi
  success "AOT library verified: usr/lib/libapp.so"

  # Flutter data (icudtl.dat, flutter_assets/) → usr/data/
  if [ -d "$BUNDLE_DIR/data" ]; then
    cp -r "$BUNDLE_DIR/data/." "$APPDIR/usr/data/"
  fi

  # ── AppRun ──
  cat > "$APPDIR/AppRun" <<'EOF'
#!/bin/bash
HERE="$(dirname "$(readlink -f "${0}")")"
export LD_LIBRARY_PATH="$HERE/usr/lib:${LD_LIBRARY_PATH:-}"
exec "$HERE/usr/visual_song_book" "$@"
EOF
  chmod +x "$APPDIR/AppRun"

  # ── Desktop entry ──
  cat > "$APPDIR/${BINARY_NAME}.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Visual Song Book
GenericName=Church Hymnal & Projection App
Comment=A premium church hymnal management & live projection app
Exec=visual_song_book
Icon=visual_song_book
Categories=AudioVideo;Music;Utility;
Keywords=hymn;church;projection;bible;song;
Terminal=false
StartupWMClass=visual_song_book
EOF

  # Copy desktop entry into standard location too
  cp "$APPDIR/${BINARY_NAME}.desktop" "$APPDIR/usr/share/applications/"

  # ── Icon ──
  local ICON_SRC=""
  # Try multiple candidate locations
  for candidate in \
    "$PROJECT_DIR/assets/images/logo.png" \
    "$PROJECT_DIR/linux/runner/resources/my_application.png" \
    "$PROJECT_DIR/assets/icons/icon.png"
  do
    if [ -f "$candidate" ]; then
      ICON_SRC="$candidate"
      break
    fi
  done

  if [ -n "$ICON_SRC" ]; then
    cp "$ICON_SRC" "$APPDIR/${BINARY_NAME}.png"
    cp "$ICON_SRC" "$APPDIR/usr/share/icons/hicolor/256x256/apps/${BINARY_NAME}.png"
    # Symlink .DirIcon for AppImage spec
    ln -sf "${BINARY_NAME}.png" "$APPDIR/.DirIcon"
    success "Icon set from: $ICON_SRC"
  else
    warn "No icon found — AppImage will have no icon. Add assets/images/logo.png"
  fi

  success "AppDir assembled."
}

# ─── Package AppImage ─────────────────────────────────────────────────────────
package_appimage() {
  info "Packaging AppImage → $OUTPUT_APPIMAGE..."

  # appimagetool requires FUSE; use --appimage-extract-and-run if unavailable
  local EXTRA_ARGS=""
  if ! fusermount --version &>/dev/null 2>&1; then
    EXTRA_ARGS="--appimage-extract-and-run"
    warn "FUSE not available — using --appimage-extract-and-run fallback"
  fi

  ARCH="$ARCH" "$APPIMAGE_TOOL" $EXTRA_ARGS "$APPDIR" "$OUTPUT_APPIMAGE"

  chmod +x "$OUTPUT_APPIMAGE"
  success "AppImage created: $OUTPUT_APPIMAGE"
  info "Size: $(du -sh "$OUTPUT_APPIMAGE" | cut -f1)"
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
  echo ""
  echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║   Visual Song Book — AppImage Builder v${VERSION}   ║${NC}"
  echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
  echo ""

  local SKIP_BUILD=false
  for arg in "$@"; do
    case "$arg" in
      --skip-build) SKIP_BUILD=true ;;
      --help|-h)
        echo "Usage: $0 [--skip-build]"
        echo "  --skip-build  Skip flutter build, repackage existing bundle"
        exit 0
        ;;
    esac
  done

  check_flutter
  ensure_appimagetool

  if [ "$SKIP_BUILD" = false ]; then
    build_flutter
  else
    warn "Skipping Flutter build (--skip-build flag set)"
  fi

  assemble_appdir
  package_appimage

  echo ""
  echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║  ✓ Done! AppImage ready for distribution               ║${NC}"
  echo -e "${GREEN}║  → ${OUTPUT_APPIMAGE}  ${NC}"
  echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo "  Test with:  chmod +x '${OUTPUT_APPIMAGE}' && '${OUTPUT_APPIMAGE}'"
}

main "$@"
