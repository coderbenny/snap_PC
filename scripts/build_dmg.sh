#!/bin/bash
# build_dmg.sh — Build a signed, distributable macOS DMG for Snapit.
#
# Ad-hoc (no Apple Developer account):
#   ./scripts/build_dmg.sh
#
# With a real Developer ID (required for notarized / no-warning distribution):
#   SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/build_dmg.sh
#
# Full notarized build (also set APPLE_ID, APPLE_TEAM_ID, APPLE_APP_PASSWORD):
#   SIGN_IDENTITY="..." NOTARIZE=1 ./scripts/build_dmg.sh
set -euo pipefail

cd "$(dirname "$0")/.."

# ── Configuration ──────────────────────────────────────────────────────────────
VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}' | cut -d'+' -f1)
APP_NAME="Snapit.app"
DMG_NAME="Snapit-${VERSION}.dmg"
RELEASE_DIR="build/macos/Build/Products/Release"
STAGE_DIR="build/dmg_stage"
ENTITLEMENTS="macos/Runner/Release.entitlements"

# Signing identity: "-" = ad-hoc (no certificate needed).
# Override: SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
NOTARIZE="${NOTARIZE:-0}"

# ── Build ──────────────────────────────────────────────────────────────────────
echo "▸ Building macOS release ${VERSION}..."
flutter build macos --release

# ── Stage ──────────────────────────────────────────────────────────────────────
echo "▸ Staging app bundle..."
rm -rf "${STAGE_DIR}"
mkdir -p "${STAGE_DIR}"
cp -R "${RELEASE_DIR}/${APP_NAME}" "${STAGE_DIR}/${APP_NAME}"

# ── Sign ───────────────────────────────────────────────────────────────────────
# macOS requires every nested binary to be signed BEFORE the outer bundle is
# sealed. Signing order: deepest first, then the .app itself.
echo "▸ Signing app bundle (identity: '${SIGN_IDENTITY}')..."

BASE_FLAGS=(--force --sign "${SIGN_IDENTITY}" --timestamp=none)
if [ "${SIGN_IDENTITY}" != "-" ]; then
    # Hardened Runtime is required for notarization with a real Developer ID.
    BASE_FLAGS+=(--options runtime --entitlements "${ENTITLEMENTS}")
fi

# 1. Sign every .dylib inside frameworks
find "${STAGE_DIR}/${APP_NAME}/Contents/Frameworks" -name "*.dylib" 2>/dev/null | \
while read -r lib; do
    codesign "${BASE_FLAGS[@]}" "${lib}" 2>/dev/null || true
done

# 2. Sign each .framework bundle (inner binaries first, then the bundle itself)
find "${STAGE_DIR}/${APP_NAME}/Contents/Frameworks" \
     -maxdepth 1 -name "*.framework" -type d | \
while read -r fw; do
    # Sign executables inside the framework Versions
    find "${fw}" -type f -perm +111 2>/dev/null | while read -r bin; do
        codesign "${BASE_FLAGS[@]}" "${bin}" 2>/dev/null || true
    done
    codesign "${BASE_FLAGS[@]}" "${fw}"
done

# 3. Sign the main executable
codesign "${BASE_FLAGS[@]}" \
    "${STAGE_DIR}/${APP_NAME}/Contents/MacOS/Snapit"

# 4. Seal the outer .app (--deep catches anything missed above)
OUTER_FLAGS=(--force --sign "${SIGN_IDENTITY}" --timestamp=none --deep)
if [ "${SIGN_IDENTITY}" != "-" ]; then
    OUTER_FLAGS+=(--options runtime --entitlements "${ENTITLEMENTS}")
fi
codesign "${OUTER_FLAGS[@]}" "${STAGE_DIR}/${APP_NAME}"

echo "▸ Verifying signature..."
codesign --verify --deep --strict "${STAGE_DIR}/${APP_NAME}" \
    && echo "  ✓ Signature valid"

# ── Notarize (Developer ID only) ──────────────────────────────────────────────
if [ "${NOTARIZE}" = "1" ] && [ "${SIGN_IDENTITY}" != "-" ]; then
    echo "▸ Notarizing (this can take a few minutes)..."
    : "${APPLE_ID:?Set APPLE_ID for notarization}"
    : "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID for notarization}"
    : "${APPLE_APP_PASSWORD:?Set APPLE_APP_PASSWORD for notarization}"

    ditto -c -k --keepParent "${STAGE_DIR}/${APP_NAME}" /tmp/Snapit-notarize.zip
    xcrun notarytool submit /tmp/Snapit-notarize.zip \
        --apple-id "${APPLE_ID}" \
        --team-id "${APPLE_TEAM_ID}" \
        --password "${APPLE_APP_PASSWORD}" \
        --wait
    xcrun stapler staple "${STAGE_DIR}/${APP_NAME}"
    rm /tmp/Snapit-notarize.zip
    echo "  ✓ Notarization stapled"
fi

# ── Helper script for ad-hoc builds ──────────────────────────────────────────
# Users who see "Snapit is damaged" can double-click this to remove the
# quarantine flag macOS attaches to internet-downloaded apps.
if [ "${SIGN_IDENTITY}" = "-" ]; then
    HELPER="${STAGE_DIR}/Fix Quarantine.command"
    cat > "${HELPER}" << 'HELPER_EOF'
#!/bin/bash
# "Fix Quarantine.command"
# macOS shows "Snapit is damaged" for apps downloaded from the internet
# that are not notarized. Double-click this once to fix it.
APP="/Applications/Snapit.app"
if [ ! -d "$APP" ]; then
    osascript -e 'display alert "Snapit.app not found" message "Please drag Snapit to Applications first, then run this script." as warning'
    exit 1
fi
xattr -cr "$APP"
echo ""
echo "✓ Done. Opening Snapit..."
open "$APP"
HELPER_EOF
    chmod +x "${HELPER}"
fi

# ── Build DMG ─────────────────────────────────────────────────────────────────
echo "▸ Removing previous DMG if present..."
rm -f "${DMG_NAME}"

echo "▸ Creating ${DMG_NAME}..."

if [ "${SIGN_IDENTITY}" = "-" ]; then
    create-dmg \
        --volname "Snapit" \
        --volicon "macos/snapit.icns" \
        --window-pos 200 120 \
        --window-size 580 420 \
        --icon-size 128 \
        --icon "${APP_NAME}" 140 190 \
        --hide-extension "${APP_NAME}" \
        --app-drop-link 430 190 \
        --icon "Fix Quarantine.command" 286 340 \
        "${DMG_NAME}" \
        "${STAGE_DIR}/"
else
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
fi

# ── Cleanup ───────────────────────────────────────────────────────────────────
echo "▸ Cleaning up staging area..."
rm -rf "${STAGE_DIR}"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "✓ Built → $(pwd)/${DMG_NAME}"
echo ""
if [ "${SIGN_IDENTITY}" = "-" ]; then
    echo "┌──────────────────────────────────────────────────────────────┐"
    echo "│  ⚠️  Ad-hoc signed (no Developer ID certificate)            │"
    echo "│                                                              │"
    echo "│  If macOS says 'Snapit is damaged':                          │"
    echo "│    1. Drag Snapit to Applications as usual                   │"
    echo "│    2. Double-click 'Fix Quarantine.command' from this DMG    │"
    echo "│    — or run in Terminal:                                     │"
    echo "│       xattr -cr /Applications/Snapit.app                    │"
    echo "│                                                              │"
    echo "│  For fully notarized builds (no user steps needed):         │"
    echo "│    Enroll in Apple Developer Program (\$99/yr), then:        │"
    echo "│    SIGN_IDENTITY='Developer ID Application: Name (ID)' \\    │"
    echo "│    NOTARIZE=1 ./scripts/build_dmg.sh                        │"
    echo "└──────────────────────────────────────────────────────────────┘"
fi
