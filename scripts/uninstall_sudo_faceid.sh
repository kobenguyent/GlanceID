#!/usr/bin/env bash
set -euo pipefail

SUDO_LOCAL="/etc/pam.d/sudo_local"
PAM_MODULE="/usr/local/lib/pam/pam_glanceid.so"

echo "Reverting GlanceID PAM sudo configuration..."
if [ -f "${SUDO_LOCAL}" ]; then
    sudo sed -i '' '/pam_glanceid\.so/d' "${SUDO_LOCAL}" || true
    echo "Removed pam_glanceid.so from ${SUDO_LOCAL}"
fi

if [ -f "${PAM_MODULE}" ]; then
    sudo rm -f "${PAM_MODULE}" || true
    echo "Removed ${PAM_MODULE}"
fi

echo "✅ GlanceID Face ID for sudo has been uninstalled."
