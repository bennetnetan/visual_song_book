#!/bin/sh
set -eu

VERSION="v18.20.4"
CACHE_DIR="${HOME}/Library/Caches/visual-song-book/nodejs-mobile-${VERSION}"
ARCHIVE="${CACHE_DIR}/nodejs-mobile-ios.zip"
BUILD_FRAMEWORK_DIR="${BUILD_DIR}/NodeMobile/${PLATFORM_NAME}"
XCFRAMEWORK="${CACHE_DIR}/NodeMobile.xcframework"

mkdir -p "${CACHE_DIR}" "${BUILD_FRAMEWORK_DIR}"
if [ ! -d "${XCFRAMEWORK}" ]; then
  curl -fL "https://github.com/nodejs-mobile/nodejs-mobile/releases/download/${VERSION}/nodejs-mobile-${VERSION}-ios.zip" -o "${ARCHIVE}.tmp"
  mv "${ARCHIVE}.tmp" "${ARCHIVE}"
  unzip -q -o "${ARCHIVE}" -d "${CACHE_DIR}"
fi

case "${PLATFORM_NAME}" in
  iphoneos) SLICE="ios-arm64" ;;
  iphonesimulator) SLICE="ios-arm64_x86_64-simulator" ;;
  *) echo "Unsupported iOS platform: ${PLATFORM_NAME}" >&2; exit 1 ;;
esac
SOURCE="${XCFRAMEWORK}/${SLICE}/NodeMobile.framework"
DEST="${BUILD_FRAMEWORK_DIR}/NodeMobile.framework"
rm -rf "${DEST}"
cp -R "${SOURCE}" "${DEST}"
