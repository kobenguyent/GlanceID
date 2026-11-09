#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "================================================="
echo " Running GlanceID Test Suite"
echo "================================================="

# Auto-detect Xcode developer directory if default CLT lacks XCTest
if [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

swift test --parallel

echo "✅ All GlanceID tests passed successfully!"
