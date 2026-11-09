#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/build_app.sh"

APP_PATH="${SCRIPT_DIR}/../build/GlanceID.app"
echo "Launching GlanceID..."
open "${APP_PATH}"
