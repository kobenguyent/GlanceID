#!/usr/bin/env bash
set -euo pipefail

echo "Resetting macOS Camera permissions for GlanceID..."
tccutil reset Camera com.kobet.glanceid || true
echo "✅ Camera permissions reset. On next launch, macOS will present the access prompt."
