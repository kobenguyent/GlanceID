#!/usr/bin/env bash
set -euo pipefail

PAM_MODULE="/usr/local/lib/pam/pam_glanceid.so"
PAM_FILES=(
    "/etc/pam.d/sudo_local"
    "/etc/pam.d/screensaver"
    "/etc/pam.d/authorization"
    "/etc/pam.d/su"
)

echo "================================================="
echo " Reverting GlanceID System Authentication Rules  "
echo "================================================="

for pam_file in "${PAM_FILES[@]}"; do
    if [ -f "${pam_file}.glanceid.bak" ]; then
        echo "Restoring ${pam_file} from backup..."
        sudo cp "${pam_file}.glanceid.bak" "${pam_file}"
        sudo rm -f "${pam_file}.glanceid.bak"
    elif [ -f "${pam_file}" ]; then
        if grep -q "pam_glanceid.so" "${pam_file}"; then
            echo "Removing GlanceID rule from ${pam_file}..."
            sudo sed -i '' '/pam_glanceid\.so/d' "${pam_file}" || true
        fi
    fi
done

if [ -f "${PAM_MODULE}" ]; then
    echo "Removing ${PAM_MODULE}..."
    sudo rm -f "${PAM_MODULE}" || true
fi

echo ""
echo "✅ All system authentication rules successfully reverted to macOS defaults."
