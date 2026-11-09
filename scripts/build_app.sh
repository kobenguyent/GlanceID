#!/usr/bin/env bash
set -euo pipefail

# GlanceID - Local macOS App Builder & Ad-Hoc Code Signer
# Works 100% without an Apple Developer Account.

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
APP_NAME="GlanceID"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "================================================="
echo " Building ${APP_NAME} for macOS (No Dev Account)"
echo "================================================="

# 1. Compile release binary using Swift Package Manager
echo "[1/5] Compiling Swift binary..."
cd "${PROJECT_DIR}"
swift build -c release

BIN_PATH="${PROJECT_DIR}/.build/release/${APP_NAME}"
if [ ! -f "${BIN_PATH}" ]; then
    echo "Error: Binary not found at ${BIN_PATH}"
    exit 1
fi

# 2. Prepare .app bundle directory structure
echo "[2/5] Creating application bundle structure..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# 3. Copy executable and metadata
echo "[3/5] Packaging binary and Info.plist..."
cp "${BIN_PATH}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

cp "${PROJECT_DIR}/Resources/Info.plist" "${CONTENTS_DIR}/Info.plist"
echo "APPL????" > "${CONTENTS_DIR}/PkgInfo"

# 4. Ad-hoc Code Signing
# Using '-' as the identity signs the app locally (Ad-Hoc), granting local TCC camera permissions
echo "[4/5] Ad-hoc code signing bundle with camera entitlements..."
ENTITLEMENTS="${PROJECT_DIR}/Resources/GlanceID.entitlements"

codesign --force --deep --sign - \
    --entitlements "${ENTITLEMENTS}" \
    "${APP_BUNDLE}"

# 5. Clear quarantine attributes to prevent Gatekeeper blockage
echo "[5/5] Removing quarantine flags..."
xattr -cr "${APP_BUNDLE}"

# Verify code sign
echo "Verifying code signature:"
codesign --verify --deep --strict --verbose=1 "${APP_BUNDLE}"

echo ""
echo "✅ Build Successful!"
echo "Bundle created at: ${APP_BUNDLE}"
