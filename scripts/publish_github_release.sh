#!/usr/bin/env bash
set -euo pipefail

# Standalone GitHub Release Script for Juice
#
# This script only handles the GitHub portion:
# 1. Commits any version changes (specifically in pbxproj).
# 2. Tags the release and pushes to origin.
# 3. Generates release notes from recent git log.
# 4. Creates a GitHub release and uploads artifacts from the dist/ folder.
#
# Usage:
#   ./scripts/publish_github_release.sh <version>
#   e.g., ./scripts/publish_github_release.sh 1.0.2

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PBXPROJ="$ROOT_DIR/Juice.xcodeproj/project.pbxproj"
DIST_DIR="$ROOT_DIR/dist"
APPCAST_PATH="$ROOT_DIR/dist/appcast.xml"

# --- Configuration ---
# Set the target GitHub repository for artifacts. 
# Default: tbwfdu/juice (main repo). Can be overridden via environment.
GITHUB_REPO="${GITHUB_REPO:-tbwfdu/juice}"

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <version>"
    echo ""
    echo "Environment Variables (optional):"
    echo "  GITHUB_REPO    Override the target repository (default: $GITHUB_REPO)"
    exit 1
fi

VERSION="$1"
RELEASE_NOTES_FILE="$DIST_DIR/release_notes.md"
ZIP_FILE="$DIST_DIR/Juice-$VERSION.zip"
PKG_FILE="$DIST_DIR/Juice-Installer-$VERSION.pkg"

# 1. Check for gh CLI
if ! command -v gh >/dev/null 2>&1; then
    echo "Error: 'gh' CLI not found. Please install it with 'brew install gh' and authenticate with 'gh auth login'."
    exit 1
fi

# 2. Verify artifacts exist
if [[ ! -f "$ZIP_FILE" ]]; then
    echo "Error: ZIP artifact not found at $ZIP_FILE"
    exit 1
fi
if [[ ! -f "$PKG_FILE" ]]; then
    echo "Error: PKG artifact not found at $PKG_FILE"
    exit 1
fi

# 3. Generate Release Notes
echo "==> Generating release notes..."
echo "## Juice $VERSION" > "$RELEASE_NOTES_FILE"
echo "" >> "$RELEASE_NOTES_FILE"
echo "### Changes in this release" >> "$RELEASE_NOTES_FILE"
# Get commits since the last tag, or last 5 if no tags found
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
if [[ -n "$LAST_TAG" ]]; then
    git log "${LAST_TAG}..HEAD" --pretty=format:"* %s" >> "$RELEASE_NOTES_FILE"
else
    git log -n 5 --pretty=format:"* %s" >> "$RELEASE_NOTES_FILE"
fi
echo "" >> "$RELEASE_NOTES_FILE"

# 4. Git Operations
echo "==> Staging and tagging release v$VERSION..."
git add "$PBXPROJ"
if git diff --cached --quiet; then
    echo "No project changes to commit."
else
    git commit -m "Release v$VERSION"
fi

# Create and push tag
TAG_NAME="v$VERSION"
if git rev-parse "$TAG_NAME" >/dev/null 2>&1; then
    echo "Warning: Tag $TAG_NAME already exists locally. Deleting and re-creating..."
    git tag -d "$TAG_NAME"
fi
git tag "$TAG_NAME"
git push origin main "$TAG_NAME"

# 5. Create GitHub Release
echo "==> Creating GitHub Release $TAG_NAME in repo $GITHUB_REPO..."
gh release create "$TAG_NAME" \
    --repo "$GITHUB_REPO" \
    --title "Juice $VERSION" \
    --notes-file "$RELEASE_NOTES_FILE" \
    "$ZIP_FILE" \
    "$PKG_FILE" \
    "$APPCAST_PATH"

echo "==> Successfully published $TAG_NAME to $GITHUB_REPO."
