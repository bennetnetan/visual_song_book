#!/bin/sh
set -eu

ROOT="$SRCROOT/.."
DEST="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/converter"
NODE_BIN="$(command -v node || true)"

if [ -z "$NODE_BIN" ] || [ ! -x "$NODE_BIN" ]; then
  echo 'Node.js is required to bundle the VSB converter.' >&2
  exit 1
fi
if [ ! -f "$ROOT/node_modules/mdb-reader/package.json" ] ||
   [ ! -f "$ROOT/node_modules/archiver/package.json" ]; then
  echo 'Run npm ci --omit=dev before building macOS.' >&2
  exit 1
fi

mkdir -p "$DEST/tools" "$DEST/node_modules"
cp "$NODE_BIN" "$DEST/node"
chmod +x "$DEST/node"
cp "$ROOT/tools/convert_vsb_to_vsbook.mjs" "$DEST/tools/"
cp -R "$ROOT/node_modules/." "$DEST/node_modules/"

NODE_LICENSE="$(dirname "$NODE_BIN")/LICENSE"
if [ ! -f "$NODE_LICENSE" ]; then
  NODE_LICENSE="$(dirname "$(dirname "$NODE_BIN")")/LICENSE"
fi
if [ -f "$NODE_LICENSE" ]; then
  cp "$NODE_LICENSE" "$DEST/LICENSE"
fi

if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY:--}" "$DEST/node"
fi
