#!/bin/bash
# build_pkg.sh — Build a distributable macOS PKG installer for Snapit.
#
# No Apple Developer account required.
#
# Usage:
#   ./scripts/build_pkg.sh
#
# What the user experiences:
#   1. Double-click Snapit-x.x.x.pkg  →  macOS shows a one-time warning
#   2. System Settings → Privacy & Security → click "Open Anyway"
#   3. Click through the installer wizard (Next → Install → Done)
#   4. Snapit is in /Applications and works immediately — no extra steps
#
# The PKG's postinstall script runs as root via macOS's trusted installer
# process, so it can remove the quarantine xattr automatically. This is why
# users never see the "Snapit is damaged" Gatekeeper error.
set -euo pipefail

cd "$(dirname "$0")/.."

# ── Configuration ──────────────────────────────────────────────────────────────
VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}' | cut -d'+' -f1)
APP_NAME="Snapit.app"
PKG_NAME="Snapit-${VERSION}.pkg"
RELEASE_DIR="build/macos/Build/Products/Release"
PAYLOAD_DIR="build/pkg_payload"
SCRIPTS_DIR="build/pkg_scripts"
BUNDLE_ID="ink.snapit.desktop"

# ── Build ──────────────────────────────────────────────────────────────────────
echo "▸ Building macOS release ${VERSION}..."
flutter build macos --release

# ── Prepare payload ────────────────────────────────────────────────────────────
echo "▸ Preparing app bundle..."
rm -rf "${PAYLOAD_DIR}" "${SCRIPTS_DIR}"
mkdir -p "${PAYLOAD_DIR}/Applications" "${SCRIPTS_DIR}"
cp -R "${RELEASE_DIR}/${APP_NAME}" "${PAYLOAD_DIR}/Applications/${APP_NAME}"

# ── Ad-hoc sign ────────────────────────────────────────────────────────────────
# Sign binaries so macOS doesn't complain about unsigned code within the bundle.
# Deepest-first: dylibs → frameworks → main binary → outer app.
echo "▸ Ad-hoc signing app bundle..."

find "${PAYLOAD_DIR}/Applications/${APP_NAME}/Contents/Frameworks" \
     -name "*.dylib" 2>/dev/null | while read -r lib; do
    codesign --force --sign - --timestamp=none "${lib}" 2>/dev/null || true
done

find "${PAYLOAD_DIR}/Applications/${APP_NAME}/Contents/Frameworks" \
     -maxdepth 1 -name "*.framework" -type d 2>/dev/null | while read -r fw; do
    find "${fw}" -type f -perm +111 2>/dev/null | while read -r bin; do
        codesign --force --sign - --timestamp=none "${bin}" 2>/dev/null || true
    done
    codesign --force --sign - --timestamp=none "${fw}" 2>/dev/null || true
done

codesign --force --sign - --timestamp=none \
    "${PAYLOAD_DIR}/Applications/${APP_NAME}/Contents/MacOS/Snapit"

codesign --force --sign - --timestamp=none --deep \
    "${PAYLOAD_DIR}/Applications/${APP_NAME}"

# ── Postinstall script ─────────────────────────────────────────────────────────
# This runs as root inside macOS's trusted installer process — NOT as a
# quarantined download — so xattr -cr succeeds without any user interaction.
cat > "${SCRIPTS_DIR}/postinstall" << 'POSTINSTALL'
#!/bin/bash
# Remove the quarantine flag macOS adds to internet-downloaded content.
# The PKG installer runs this as root, so it always succeeds.
xattr -cr /Applications/Snapit.app 2>/dev/null || true
exit 0
POSTINSTALL
chmod +x "${SCRIPTS_DIR}/postinstall"

# ── Build PKG ─────────────────────────────────────────────────────────────────
echo "▸ Building ${PKG_NAME}..."
rm -f "${PKG_NAME}"

pkgbuild \
    --root "${PAYLOAD_DIR}" \
    --scripts "${SCRIPTS_DIR}" \
    --identifier "${BUNDLE_ID}" \
    --version "${VERSION}" \
    --install-location "/" \
    "${PKG_NAME}"

# ── Cleanup ───────────────────────────────────────────────────────────────────
echo "▸ Cleaning up..."
rm -rf "${PAYLOAD_DIR}" "${SCRIPTS_DIR}"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "✓ Built → $(pwd)/${PKG_NAME}"
echo ""
echo "┌──────────────────────────────────────────────────────────────────┐"
echo "│  Install instructions for end users (do this once):             │"
echo "│                                                                  │"
echo "│  1. Double-click ${PKG_NAME}                    │"
echo "│     macOS shows a warning — click OK to dismiss it              │"
echo "│                                                                  │"
echo "│  2. Open System Settings → Privacy & Security                   │"
echo "│     Scroll down and click \"Open Anyway\" next to ${PKG_NAME} │"
echo "│                                                                  │"
echo "│  3. Click through the installer: Continue → Install → Close     │"
echo "│                                                                  │"
echo "│  4. Snapit is in /Applications — open it normally from now on   │"
echo "│     No 'damaged' warning. No Terminal. Nothing else to do.      │"
echo "│                                                                  │"
echo "│  (Once you have an Apple Developer ID, run build_dmg.sh with    │"
echo "│   SIGN_IDENTITY and NOTARIZE=1 for zero-step installs.)         │"
echo "└──────────────────────────────────────────────────────────────────┘"
