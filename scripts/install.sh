#!/usr/bin/env bash
set -euo pipefail

# GlanceID - Local MacBook Pro Installer
# Installs GlanceID directly without an Apple Developer Account.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# 1. Build the app bundle
"${SCRIPT_DIR}/build_app.sh"

APP_SOURCE="${PROJECT_DIR}/build/GlanceID.app"

# 2. Determine destination directory
# Prefer /Applications if user has write permissions, otherwise install to ~/Applications
TARGET_DIR="/Applications"
if [ ! -w "${TARGET_DIR}" ]; then
    TARGET_DIR="${HOME}/Applications"
    mkdir -p "${TARGET_DIR}"
fi

TARGET_APP="${TARGET_DIR}/GlanceID.app"

echo ""
echo "================================================="
echo " Installing GlanceID to ${TARGET_APP}"
echo "================================================="

# Remove previous installed version if exists
if [ -d "${TARGET_APP}" ]; then
    echo "Replacing previous installation..."
    rm -rf "${TARGET_APP}"
fi

cp -R "${APP_SOURCE}" "${TARGET_APP}"
xattr -cr "${TARGET_APP}"

echo "✅ GlanceID successfully installed to ${TARGET_APP}!"
echo ""
echo "🚀 To launch the app, run:"
echo "   open \"${TARGET_APP}\""
echo ""
echo "💡 First Launch Camera Access Note:"
echo "   macOS will prompt: 'GlanceID would like to access the camera'."
echo "   Click 'OK' to enable Face ID simulation."
echo "================================================="
