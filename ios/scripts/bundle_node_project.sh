#!/bin/sh
set -eu

RESOURCE_DIR="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/NodeProject"
FRAMEWORK_DIR="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
SOURCE_ROOT="${SRCROOT}/.."

if [ ! -d "${SOURCE_ROOT}/node_modules/mdb-reader" ] || [ ! -d "${SOURCE_ROOT}/node_modules/archiver" ]; then
  echo "error: Run npm ci --omit=dev at the repository root before building iOS." >&2
  exit 1
fi

rm -rf "${RESOURCE_DIR}"
mkdir -p "${RESOURCE_DIR}/tools"
cp "${SOURCE_ROOT}/tools/convert_vsb_to_vsbook.mjs" "${RESOURCE_DIR}/tools/"
cp "${SOURCE_ROOT}/package.json" "${RESOURCE_DIR}/"
cp -R "${SOURCE_ROOT}/node_modules" "${RESOURCE_DIR}/"
cp "${SRCROOT}/Runner/NodeProject/mobile_server.mjs" "${RESOURCE_DIR}/"

mkdir -p "${FRAMEWORK_DIR}"
rm -rf "${FRAMEWORK_DIR}/NodeMobile.framework"
cp -R "${BUILD_DIR}/NodeMobile/${PLATFORM_NAME}/NodeMobile.framework" "${FRAMEWORK_DIR}/"
if [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]; then
  /usr/bin/codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY}" --preserve-metadata=identifier,entitlements "${FRAMEWORK_DIR}/NodeMobile.framework"
fi
