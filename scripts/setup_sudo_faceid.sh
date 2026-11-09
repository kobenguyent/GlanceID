#!/usr/bin/env bash
set -euo pipefail

# GlanceID - Face ID for Terminal 'sudo' Setup
# Installs pam_glanceid.so and configures /etc/pam.d/sudo_local

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PAM_SOURCE="${PROJECT_DIR}/pam/pam_glanceid.c"
PAM_INSTALL_DIR="/usr/local/lib/pam"
PAM_MODULE="${PAM_INSTALL_DIR}/pam_glanceid.so"
SUDO_LOCAL="/etc/pam.d/sudo_local"

echo "================================================="
echo " Setting up GlanceID Face ID for macOS 'sudo'   "
echo "================================================="

# 1. Compile the PAM shared library
echo "[1/4] Compiling pam_glanceid.so..."
mkdir -p "${PROJECT_DIR}/pam"
clang -shared -o "${PROJECT_DIR}/pam/pam_glanceid.so" "${PAM_SOURCE}" -lpam
codesign --force --sign - "${PROJECT_DIR}/pam/pam_glanceid.so"

# 2. Install to /usr/local/lib/pam
echo "[2/4] Installing PAM module to ${PAM_INSTALL_DIR} (requires sudo)..."
sudo mkdir -p "${PAM_INSTALL_DIR}"
sudo cp "${PROJECT_DIR}/pam/pam_glanceid.so" "${PAM_MODULE}"
sudo chmod 755 "${PAM_MODULE}"

# 3. Configure /etc/pam.d/sudo_local
echo "[3/4] Configuring ${SUDO_LOCAL}..."
if [ ! -f "${SUDO_LOCAL}" ]; then
    echo "# sudo_local: GlanceID Face ID configuration" | sudo tee "${SUDO_LOCAL}" > /dev/null
fi

if grep -q "pam_glanceid.so" "${SUDO_LOCAL}"; then
    echo "GlanceID PAM module is already active in ${SUDO_LOCAL}."
else
    # Prepend auth line to top of sudo_local
    TEMP_FILE=$(mktemp)
    echo "auth       sufficient     ${PAM_MODULE}" > "${TEMP_FILE}"
    cat "${SUDO_LOCAL}" >> "${TEMP_FILE}"
    sudo cp "${TEMP_FILE}" "${SUDO_LOCAL}"
    sudo chmod 644 "${SUDO_LOCAL}"
    rm -f "${TEMP_FILE}"
    echo "Added GlanceID to ${SUDO_LOCAL}."
fi

echo ""
echo "================================================="
echo "✅ Face ID for 'sudo' is now configured!"
echo "Test it now in a new terminal window by running:"
echo "   sudo ls"
echo "Look at your Mac camera to authenticate!"
echo "================================================="
