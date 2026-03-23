#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/installer/build"
DERIVED_DATA="${DERIVED_DATA:-$BUILD_DIR/DerivedDataAppOnly}"
DIST_DIR="$ROOT_DIR/dist"
STAGE_DIR="$BUILD_DIR/app-only-stage"

APP_NAME="${APP_NAME:-Juice.app}"
SCHEME="${SCHEME:-Juice}"
CONFIGURATION="${CONFIGURATION:-Release}"

UNSIGNED="${UNSIGNED:-0}"
APP_SIGN_IDENTITY="${APP_SIGN_IDENTITY:-}"
APP_ENTITLEMENTS="${APP_ENTITLEMENTS:-$ROOT_DIR/Juice/Juice.entitlements}"
WIDGET_ENTITLEMENTS="${WIDGET_ENTITLEMENTS:-$ROOT_DIR/JuiceWidgetExtension/JuiceWidgetExtension.entitlements}"

OUTPUT_APP="$DIST_DIR/$APP_NAME"
SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-}"

find_developer_id_application() {
  security find-identity -v -p codesigning 2>/dev/null \
    | awk -F '"' '/Developer ID Application/ {print $2; exit}'
}

mkdir -p "$BUILD_DIR" "$DIST_DIR"

echo "==> Building $SCHEME ($CONFIGURATION)"
xcodebuild \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -sdk macosx \
  -derivedDataPath "$DERIVED_DATA" \
  build

APP_SOURCE="$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME"
if [[ ! -d "$APP_SOURCE" ]]; then
  APP_SOURCE="$(find "$DERIVED_DATA/Build/Products/$CONFIGURATION" -maxdepth 1 -type d -name "*.app" | head -n 1 || true)"
fi
if [[ -z "$APP_SOURCE" || ! -d "$APP_SOURCE" ]]; then
  echo "error: could not locate built app in $DERIVED_DATA/Build/Products/$CONFIGURATION" >&2
  exit 1
fi

echo "==> Staging app"
rm -rf "$STAGE_DIR" "$OUTPUT_APP"
mkdir -p "$STAGE_DIR"
cp -R "$APP_SOURCE" "$STAGE_DIR/$APP_NAME"

if [[ -n "$SPARKLE_FEED_URL" ]]; then
  APP_INFO_PLIST_STAGE="$STAGE_DIR/$APP_NAME/Contents/Info.plist"
  if [[ -f "$APP_INFO_PLIST_STAGE" ]]; then
    echo "==> Injecting Sparkle feed URL into staged Info.plist"
    /usr/libexec/PlistBuddy -c "Set :SUFeedURL $SPARKLE_FEED_URL" "$APP_INFO_PLIST_STAGE" >/dev/null 2>&1 \
      || /usr/libexec/PlistBuddy -c "Add :SUFeedURL string $SPARKLE_FEED_URL" "$APP_INFO_PLIST_STAGE"
  fi
fi

if [[ "$UNSIGNED" != "1" ]]; then
  if [[ -z "$APP_SIGN_IDENTITY" ]]; then
    APP_SIGN_IDENTITY="$(find_developer_id_application || true)"
  fi
  if [[ -z "$APP_SIGN_IDENTITY" ]]; then
    echo "error: no Developer ID Application cert found. Set APP_SIGN_IDENTITY or run with UNSIGNED=1" >&2
    exit 1
  fi
  if [[ ! -f "$APP_ENTITLEMENTS" ]]; then
    echo "error: app entitlements file not found: $APP_ENTITLEMENTS" >&2
    exit 1
  fi
  if [[ ! -f "$WIDGET_ENTITLEMENTS" ]]; then
    echo "error: widget entitlements file not found: $WIDGET_ENTITLEMENTS" >&2
    exit 1
  fi

  echo "==> Signing embedded extensions"
  if [[ -d "$STAGE_DIR/$APP_NAME/Contents/PlugIns" ]]; then
    while IFS= read -r appex; do
      codesign \
        --force \
        --timestamp \
        --options runtime \
        --entitlements "$WIDGET_ENTITLEMENTS" \
        --sign "$APP_SIGN_IDENTITY" \
        "$appex"
    done < <(find "$STAGE_DIR/$APP_NAME/Contents/PlugIns" -maxdepth 1 -type d -name "*.appex" | sort)
  fi

  echo "==> Signing embedded frameworks"
  if [[ -d "$STAGE_DIR/$APP_NAME/Contents/Frameworks" ]]; then
    while IFS= read -r framework; do
      if [[ "$framework" == *.framework ]]; then
        # Sparkle embeds nested XPC services and helper apps that must be signed too.
        codesign \
          --force \
          --deep \
          --timestamp \
          --options runtime \
          --sign "$APP_SIGN_IDENTITY" \
          "$framework"
      else
        codesign \
          --force \
          --timestamp \
          --options runtime \
          --sign "$APP_SIGN_IDENTITY" \
          "$framework"
      fi
    done < <(find "$STAGE_DIR/$APP_NAME/Contents/Frameworks" -maxdepth 1 -type d \( -name "*.framework" -o -name "*.dylib" \) | sort)
  fi

  echo "==> Signing app"
  codesign \
    --force \
    --timestamp \
    --options runtime \
    --entitlements "$APP_ENTITLEMENTS" \
    --sign "$APP_SIGN_IDENTITY" \
    "$STAGE_DIR/$APP_NAME"
else
  echo "==> UNSIGNED=1, skipping signing"
fi

echo "==> Verifying app signature"
codesign --verify --deep --strict --verbose=2 "$STAGE_DIR/$APP_NAME"

echo "==> Exporting app bundle"
cp -R "$STAGE_DIR/$APP_NAME" "$OUTPUT_APP"

if ! spctl --assess --type execute -vv "$OUTPUT_APP"; then
  echo "warning: spctl assessment failed (expected if not notarized)"
fi

echo "==> Done"
echo "$OUTPUT_APP"
