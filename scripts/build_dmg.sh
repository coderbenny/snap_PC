#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}' | cut -d'+' -f1)
APP_NAME="Snapit.app"
DMG_NAME="Snapit-${VERSION}.dmg"
RELEASE_DIR="build/macos/Build/Products/Release"
STAGE_DIR="build/dmg_stage"

echo "▸ Building macOS release (version ${VERSION})..."
flutter build macos --release

echo "▸ Staging app bundle..."
rm -rf "${STAGE_DIR}"
mkdir -p "${STAGE_DIR}"
cp -R "${RELEASE_DIR}/${APP_NAME}" "${STAGE_DIR}/${APP_NAME}"

echo "▸ Removing previous DMG if present..."
rm -f "${DMG_NAME}"

echo "▸ Creating ${DMG_NAME}..."
create-dmg \
  --volname "Snapit" \
  --volicon "macos/snapit.icns" \
  --window-pos 200 120 \
  --window-size 540 380 \
  --icon-size 128 \
  --icon "${APP_NAME}" 130 180 \
  --hide-extension "${APP_NAME}" \
  --app-drop-link 400 180 \
  "${DMG_NAME}" \
  "${STAGE_DIR}/"

echo "▸ Cleaning up staging area..."
rm -rf "${STAGE_DIR}"

echo "✓ Done → $(pwd)/${DMG_NAME}"
