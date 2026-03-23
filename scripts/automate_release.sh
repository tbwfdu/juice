#!/usr/bin/env bash
set -euo pipefail

# Juice Release Automation Script
#
# This script automates the entire release process:
# 1. Increments the version in the Xcode project.
# 2. Builds and signs the app and Sparkle update.
# 3. Builds and notarizes the .pkg installer.
# 4. Updates the appcast.xml with the new release item.
# 5. Creates a GitHub release and uploads all artifacts.
#
# Prerequisites:
# - 'gh' CLI installed and authenticated (brew install gh)
# - 'notarytool' credentials stored (see scripts/full_build_and_notarize.sh)
# - Sparkle 'sign_update' tool available in PATH
# - Environment variables set: NOTARY_PROFILE, APP_SIGN_IDENTITY, PKG_SIGN_IDENTITY

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PBXPROJ="$ROOT_DIR/Juice.xcodeproj/project.pbxproj"
DIST_DIR="$ROOT_DIR/dist"
APPCAST_PATH="$ROOT_DIR/dist/appcast.xml" # Adjust this to your stable appcast location
# --- Configuration ---
NOTARY_PROFILE="${NOTARY_PROFILE:-juice-notary}"
APP_SIGN_IDENTITY="${APP_SIGN_IDENTITY:-Developer ID Application: Peter Lindley (ZV33P8H324)}"
PKG_SIGN_IDENTITY="${PKG_SIGN_IDENTITY:-Developer ID Installer: Peter Lindley (ZV33P8H324)}"
# Sparkle EdDSA private key should be in keychain or provided via SPARKLE_PRIVATE_KEY_PATH

# GitHub Configuration
GITHUB_REPO="${GITHUB_REPO:-tbwfdu/juice}"

# Azure Storage Configuration for Appcast
AZURE_STORAGE_ACCOUNT="${AZURE_STORAGE_ACCOUNT:-}"
AZURE_STORAGE_KEY="${AZURE_STORAGE_KEY:-}"
AZURE_STORAGE_SHARE="${AZURE_STORAGE_SHARE:-}"
AZURE_STORAGE_PATH="${AZURE_STORAGE_PATH:-appcast.xml}"

usage() {
  cat <<USAGE
Usage:
  ./scripts/automate_release.sh [next_version]

If next_version is omitted, the patch version will be incremented (e.g., 1.0.1 -> 1.0.2).

Required environment for Azure upload:
  AZURE_STORAGE_ACCOUNT
  AZURE_STORAGE_KEY
  AZURE_STORAGE_SHARE
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

# --- 1. Version Management ---
CURRENT_VERSION=$(grep "MARKETING_VERSION =" "$PBXPROJ" | head -n 1 | sed -E 's/.*= ([0-9.]+);/\1/')
CURRENT_BUILD=$(grep "CURRENT_PROJECT_VERSION =" "$PBXPROJ" | head -n 1 | sed -E 's/.*= ([0-9]+);/\1/')

NEXT_VERSION="${1:-}"
if [[ -z "$NEXT_VERSION" ]]; then
    # Auto-increment patch version
    IFS='.' read -r major minor patch <<< "$CURRENT_VERSION"
    NEXT_VERSION="$major.$minor.$((patch + 1))"
fi
NEXT_BUILD=$((CURRENT_BUILD + 1))
FULL_TAG="v1.0.0.${NEXT_BUILD}"

echo "==> Incrementing version: $CURRENT_VERSION ($CURRENT_BUILD) -> $NEXT_VERSION ($NEXT_BUILD)"
sed -i '' "s/MARKETING_VERSION = [0-9.]*;/MARKETING_VERSION = $NEXT_VERSION;/g" "$PBXPROJ"
sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = $NEXT_BUILD;/g" "$PBXPROJ"

# --- 2. Build App & Sparkle Update ---
echo "==> Building App and Sparkle Update..."
export NOTARY_PROFILE APP_SIGN_IDENTITY FULL_TAG NEXT_VERSION NEXT_BUILD
"$ROOT_DIR/scripts/build_app_release.sh"

# --- 3. Build & Notarize PKG ---
echo "==> Building and Notarizing .pkg Installer..."
export PKG_SIGN_IDENTITY
"$ROOT_DIR/scripts/build_pkg.sh"
"$ROOT_DIR/scripts/notarize_pkg.sh"

# --- 4. Update Appcast ---
echo "==> Updating Sparkle Appcast..."
NEW_ITEM=$("$ROOT_DIR/scripts/generate_appcast_item.sh")

if [[ -f "$APPCAST_PATH" ]]; then
    # Insert the new item at the top of the channel
    # This is a simple insertion after <language> tag to keep metadata above items
    ITEM_FILE=$(mktemp)
    echo "$NEW_ITEM" > "$ITEM_FILE"
    sed -i '' "/<language>/r $ITEM_FILE" "$APPCAST_PATH"
    rm "$ITEM_FILE"
    echo "Updated $APPCAST_PATH"
else
    echo "Warning: $APPCAST_PATH not found. Emitting item to stdout:"
    echo "$NEW_ITEM"
fi

# --- 5. Azure Upload (Appcast) ---
if [[ -n "$AZURE_STORAGE_ACCOUNT" && -n "$AZURE_STORAGE_KEY" && -n "$AZURE_STORAGE_SHARE" ]]; then
    if command -v az >/dev/null 2>&1; then
        echo "==> Uploading appcast.xml to Azure File Share..."
        az storage file upload \
            --account-name "$AZURE_STORAGE_ACCOUNT" \
            --account-key "$AZURE_STORAGE_KEY" \
            --share-name "$AZURE_STORAGE_SHARE" \
            --source "$APPCAST_PATH" \
            --path "$AZURE_STORAGE_PATH" \
            --only-show-errors
        echo "==> Successfully uploaded $APPCAST_PATH to Azure: /$AZURE_STORAGE_SHARE/$AZURE_STORAGE_PATH"
    else
        echo "Warning: 'az' CLI not found. Skipping Azure upload."
    fi
else
    echo "Warning: Azure storage credentials not set. Skipping Azure upload."
fi

# --- 6. Create Release Notes ---
RELEASE_NOTES_FILE="$DIST_DIR/release_notes.md"
TODAY=$(date "+%Y-%m-%d")
echo "## [$FULL_TAG]- $TODAY" > "$RELEASE_NOTES_FILE"
echo "### 🐛 Bug Fixes" >> "$RELEASE_NOTES_FILE"
echo "" >> "$RELEASE_NOTES_FILE"
echo "### 🆕 New Features" >> "$RELEASE_NOTES_FILE"
git log -n 10 --pretty=format:"* %s" >> "$RELEASE_NOTES_FILE"
echo "" >> "$RELEASE_NOTES_FILE"

echo "==> Generated release notes at $RELEASE_NOTES_FILE"

# --- 6. GitHub Release ---
if command -v gh >/dev/null 2>&1; then
    # The tag on GitHub follows the format v1.0.0.<build_number>
    echo "==> Creating GitHub Release $FULL_TAG..."
    
    # Stage all modified source files and the new scripts
    git add -u
    git add "$ROOT_DIR/scripts/automate_release.sh" "$ROOT_DIR/scripts/publish_github_release.sh" 2>/dev/null || true
    
    # Commit if there are changes
    if ! git diff --cached --quiet; then
        git commit -m "Release $FULL_TAG ($NEXT_VERSION)"
    else
        echo "No changes to commit."
    fi

    # Tag and push
    if git rev-parse "$FULL_TAG" >/dev/null 2>&1; then
        git tag -d "$FULL_TAG"
    fi
    git tag "$FULL_TAG"
    git push origin main "$FULL_TAG"

    # Upload artifacts
    # Artifacts are in $DIST_DIR
    ZIP_FILE="$DIST_DIR/Juice-$NEXT_VERSION.zip"
    PKG_FILE="$DIST_DIR/Juice-Installer-$NEXT_VERSION.pkg"
    
    gh release create "$FULL_TAG" \
        --repo "$GITHUB_REPO" \
        --title "Juice $NEXT_VERSION (Build $NEXT_BUILD)" \
        --notes-file "$RELEASE_NOTES_FILE" \
        "$ZIP_FILE" \
        "$PKG_FILE"

    echo "==> Release $FULL_TAG successfully created on GitHub ($GITHUB_REPO)."
else
    echo "Warning: 'gh' CLI not found. Please create the release manually at https://github.com/tbwfdu/juice/releases"
    echo "Artifacts to upload to GitHub:"
    echo "- $DIST_DIR/Juice-$NEXT_VERSION.zip"
    echo "- $DIST_DIR/Juice-Installer-$NEXT_VERSION.pkg"
fi

echo "==> All steps completed successfully."
