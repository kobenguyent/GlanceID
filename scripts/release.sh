#!/usr/bin/env bash
set -euo pipefail

# GlanceID - Automated Version Tag & GitHub Release Trigger
# Usage: ./scripts/release.sh v1.0.0

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${PROJECT_DIR}"

RAW_VERSION="${1:-v1.0.0}"
if [[ "${RAW_VERSION}" != v* ]]; then
    TAG="v${RAW_VERSION}"
else
    TAG="${RAW_VERSION}"
fi
CLEAN_VERSION="${TAG#v}"

echo "================================================="
echo " Preparing GlanceID Release ${TAG}"
echo "================================================="

# 1. Update CFBundleShortVersionString in Resources/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${CLEAN_VERSION}" "${PROJECT_DIR}/Resources/Info.plist"

# 2. Commit version bump if Info.plist changed
if ! git diff --quiet "${PROJECT_DIR}/Resources/Info.plist"; then
    git add "${PROJECT_DIR}/Resources/Info.plist"
    git commit -m "chore(release): bump version to ${CLEAN_VERSION}"
fi

# 3. Create or update git tag
if git rev-parse "${TAG}" >/dev/null 2>&1; then
    echo "Tag ${TAG} already exists locally; updating tag to HEAD..."
    git tag -fa "${TAG}" -m "GlanceID ${TAG}"
else
    git tag -a "${TAG}" -m "GlanceID ${TAG}"
fi

# 4. Push branch and tag to origin to trigger .github/workflows/release.yml
echo "Pushing main and tag ${TAG} to GitHub..."
git push origin main
git push origin "${TAG}" --force

echo ""
echo "✅ Release tag ${TAG} pushed to GitHub!"
echo "🔗 GitHub Actions is now building and publishing the release at:"
echo "   https://github.com/kobenguyent/GlanceID/releases/tag/${TAG}"
