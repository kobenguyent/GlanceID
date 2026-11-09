#!/usr/bin/env bash
set -euo pipefail

# GlanceID - System-Wide Face ID Authentication Integrator
# Configures GlanceID as default biometric authentication across macOS PAM services.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PAM_SOURCE="${PROJECT_DIR}/pam/pam_glanceid.c"
PAM_INSTALL_DIR="/usr/local/lib/pam"
PAM_MODULE="${PAM_INSTALL_DIR}/pam_glanceid.so"

echo "================================================="
echo " Deep System-Wide Face ID Integration for macOS  "
echo "================================================="

# 1. Compile and sign the latest PAM module
echo "[1/4] Compiling and code-signing pam_glanceid.so..."
mkdir -p "${PROJECT_DIR}/pam"
clang -shared -o "${PROJECT_DIR}/pam/pam_glanceid.so" "${PAM_SOURCE}" -lpam
codesign --force --sign - "${PROJECT_DIR}/pam/pam_glanceid.so"

# 2. Install to /usr/local/lib/pam
echo "[2/4] Installing PAM module to ${PAM_INSTALL_DIR} (requires sudo)..."
sudo mkdir -p "${PAM_INSTALL_DIR}"
sudo cp "${PROJECT_DIR}/pam/pam_glanceid.so" "${PAM_MODULE}"
sudo chmod 755 "${PAM_MODULE}"

# Helper function to insert pam_glanceid into a PAM configuration file
insert_pam_rule() {
    local pam_file="$1"
    local desc="$2"
    
    echo "  -> Configuring ${desc} (${pam_file})..."
    
    if [ ! -f "${pam_file}" ]; then
        echo "auth       sufficient     ${PAM_MODULE}" | sudo tee "${pam_file}" > /dev/null
        sudo chmod 644 "${pam_file}"
        return
    fi
    
    if grep -q "pam_glanceid.so" "${pam_file}"; then
        echo "     Already configured."
    else
        # Backup original
        sudo cp "${pam_file}" "${pam_file}.glanceid.bak"
        
        # Insert auth sufficient rule at the top of the auth stack
        TEMP_FILE=$(mktemp)
        awk -v rule="auth       sufficient     ${PAM_MODULE}" '
            !inserted && /^auth/ { print rule; inserted=1 }
            { print }
            END { if (!inserted) print rule }
        ' "${pam_file}" > "${TEMP_FILE}"
        
        sudo cp "${TEMP_FILE}" "${pam_file}"
        sudo chmod 644 "${pam_file}"
        rm -f "${TEMP_FILE}"
        echo "     ✅ Enabled."
    fi
}

echo "[3/4] Integrating GlanceID into macOS authentication services..."

# Service 1: Terminal & CLI sudo
insert_pam_rule "/etc/pam.d/sudo_local" "Terminal 'sudo' commands"

# Service 2: Native macOS Screensaver & Lock Screen
insert_pam_rule "/etc/pam.d/screensaver" "macOS Lock Screen & Screensaver"

# Service 3: System Administrator Authorization
insert_pam_rule "/etc/pam.d/authorization" "System Authorization Prompts"

# Service 4: Switch User (su)
insert_pam_rule "/etc/pam.d/su" "Switch User ('su') authentication"

echo ""
echo "================================================="
echo "🎉 GlanceID is now deeply integrated into macOS!"
echo ""
echo "Activated services:"
echo "  1. Terminal 'sudo'     -> Face ID glance unlocks sudo (test with: sudo -k && sudo ls)"
echo "  2. macOS Screen Lock   -> Face ID glance unlocks your real Mac screen"
echo "  3. Admin Authorization -> Face ID validates admin authorization"
echo "  4. Switch User ('su')  -> Face ID authenticates user switching"
echo ""
echo "To revert anytime, run:"
echo "   ./scripts/disable_system_faceid.sh"
echo "================================================="
