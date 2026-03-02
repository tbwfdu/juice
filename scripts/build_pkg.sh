#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER_DIR="$ROOT_DIR/installer"
BUILD_DIR="$INSTALLER_DIR/build"
DIST_DIR="$ROOT_DIR/dist"
DERIVED_DATA="$BUILD_DIR/DerivedData"
DIST_XML="$INSTALLER_DIR/Distribution.xml"

APP_PAYLOAD_ROOT="$INSTALLER_DIR/payload/app"
APP_STAGE_DIR="$APP_PAYLOAD_ROOT/Applications"
SCRIPTS_PAYLOAD_ROOT="$INSTALLER_DIR/payload/scripts"
DEPS_DIR="$INSTALLER_DIR/deps"

APP_SCRIPT_DIR="$INSTALLER_DIR/scripts/app"
RUNTIME_SCRIPT_DIR="$INSTALLER_DIR/scripts/scripts"
RESOURCES_DIR="$INSTALLER_DIR/resources"

APP_NAME="${APP_NAME:-Juice.app}"
APP_PRODUCT_NAME="${APP_PRODUCT_NAME:-Juice}"
SCHEME="${SCHEME:-Juice}"
CONFIGURATION="${CONFIGURATION:-Release}"
MIN_OS_VERSION="${MIN_OS_VERSION:-14.6}"
APP_ENTITLEMENTS="${APP_ENTITLEMENTS:-$ROOT_DIR/Juice/Juice.entitlements}"
WIDGET_ENTITLEMENTS="${WIDGET_ENTITLEMENTS:-$ROOT_DIR/JuiceWidgetExtension/JuiceWidgetExtension.entitlements}"

APP_PKG_ID="${APP_PKG_ID:-com.tbwfdu.juice.app}"
RUNTIME_PKG_ID="${RUNTIME_PKG_ID:-com.tbwfdu.juice.runtime}"

UNSIGNED="${UNSIGNED:-0}"
PKG_SIGN_IDENTITY="${PKG_SIGN_IDENTITY:-}"
APP_SIGN_IDENTITY="${APP_SIGN_IDENTITY:-}"

NOTARIZE="${NOTARIZE:-0}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

if [[ ! -d "$INSTALLER_DIR" ]]; then
  echo "error: installer directory not found at $INSTALLER_DIR" >&2
  exit 1
fi

mkdir -p "$BUILD_DIR" "$DIST_DIR" "$APP_STAGE_DIR" "$DEPS_DIR" "$RESOURCES_DIR"

APP_VERSION=""
APP_BUILD=""
STAMP="$(date +%Y%m%d-%H%M%S)"
PRODUCT_PKG=""
APP_COMPONENT_PKG="$BUILD_DIR/${APP_PKG_ID}.pkg"
RUNTIME_COMPONENT_PKG="$BUILD_DIR/${RUNTIME_PKG_ID}.pkg"

find_developer_id_installer() {
  security find-identity -v 2>/dev/null \
    | awk -F '"' '/Developer ID Installer/ {print $2; exit}'
}

find_developer_id_application() {
  security find-identity -v -p codesigning 2>/dev/null \
    | awk -F '"' '/Developer ID Application/ {print $2; exit}'
}

if [[ "$UNSIGNED" != "1" ]]; then
  if [[ -z "$PKG_SIGN_IDENTITY" ]]; then
    PKG_SIGN_IDENTITY="$(find_developer_id_installer || true)"
  fi
  if [[ -z "$PKG_SIGN_IDENTITY" ]]; then
    echo "error: no Developer ID Installer cert found. Set PKG_SIGN_IDENTITY or run with UNSIGNED=1" >&2
    exit 1
  fi
fi

if [[ -z "$APP_SIGN_IDENTITY" ]]; then
  APP_SIGN_IDENTITY="$(find_developer_id_application || true)"
fi

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

APP_INFO_PLIST="$APP_SOURCE/Contents/Info.plist"
APP_VERSION="$(
  /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_INFO_PLIST" 2>/dev/null \
  || echo "${MARKETING_VERSION:-1.0}"
)"
APP_BUILD="$(
  /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_INFO_PLIST" 2>/dev/null \
  || echo "${CURRENT_PROJECT_VERSION:-1}"
)"
PRODUCT_PKG="$DIST_DIR/Juice-Installer-${APP_VERSION}.pkg"

echo "==> Staging app payload"
rm -rf "$APP_STAGE_DIR/$APP_NAME"
cp -R "$APP_SOURCE" "$APP_STAGE_DIR/$APP_NAME"

if [[ -n "$APP_SIGN_IDENTITY" ]]; then
  echo "==> Re-signing app with Developer ID Application certificate"
  if [[ ! -f "$APP_ENTITLEMENTS" ]]; then
    echo "error: app entitlements file not found: $APP_ENTITLEMENTS" >&2
    exit 1
  fi
  if [[ ! -f "$WIDGET_ENTITLEMENTS" ]]; then
    echo "error: widget entitlements file not found: $WIDGET_ENTITLEMENTS" >&2
    exit 1
  fi
  # Re-sign embedded extensions first, then the app container.
  # Use explicit entitlements so release signing does not inherit debug entitlements.
  if [[ -d "$APP_STAGE_DIR/$APP_NAME/Contents/PlugIns" ]]; then
    while IFS= read -r appex; do
      codesign \
        --force \
        --options runtime \
        --entitlements "$WIDGET_ENTITLEMENTS" \
        --sign "$APP_SIGN_IDENTITY" \
        "$appex"
    done < <(find "$APP_STAGE_DIR/$APP_NAME/Contents/PlugIns" -maxdepth 1 -type d -name "*.appex" | sort)
  fi

  echo "==> Signing embedded frameworks"
  if [[ -d "$APP_STAGE_DIR/$APP_NAME/Contents/Frameworks" ]]; then
    while IFS= read -r framework; do
      codesign \
        --force \
        --options runtime \
        --sign "$APP_SIGN_IDENTITY" \
        "$framework"
    done < <(find "$APP_STAGE_DIR/$APP_NAME/Contents/Frameworks" -maxdepth 1 -type d \( -name "*.framework" -o -name "*.dylib" \) | sort)
  fi

  codesign \
    --force \
    --options runtime \
    --entitlements "$APP_ENTITLEMENTS" \
    --sign "$APP_SIGN_IDENTITY" \
    "$APP_STAGE_DIR/$APP_NAME"
else
  echo "==> No Developer ID Application cert found; keeping existing app signature"
fi

echo "==> Verifying staged app signature"
codesign --verify --deep --strict --verbose=2 "$APP_STAGE_DIR/$APP_NAME"

chmod +x "$INSTALLER_DIR/payload/scripts/usr/local/juice/juice_runtime_check.sh" \
  "$APP_SCRIPT_DIR/preinstall" "$APP_SCRIPT_DIR/postinstall" \
  "$RUNTIME_SCRIPT_DIR/preinstall" "$RUNTIME_SCRIPT_DIR/postinstall"

rm -f "$APP_COMPONENT_PKG" "$RUNTIME_COMPONENT_PKG"

echo "==> Building app component package"
if [[ "$UNSIGNED" != "1" ]]; then
  pkgbuild \
    --root "$APP_PAYLOAD_ROOT" \
    --scripts "$APP_SCRIPT_DIR" \
    --identifier "$APP_PKG_ID" \
    --version "$APP_VERSION" \
    --install-location "/" \
    --sign "$PKG_SIGN_IDENTITY" \
    "$APP_COMPONENT_PKG"
else
  pkgbuild \
    --root "$APP_PAYLOAD_ROOT" \
    --scripts "$APP_SCRIPT_DIR" \
    --identifier "$APP_PKG_ID" \
    --version "$APP_VERSION" \
    --install-location "/" \
    "$APP_COMPONENT_PKG"
fi

echo "==> Building runtime component package"
if [[ "$UNSIGNED" != "1" ]]; then
  pkgbuild \
    --root "$SCRIPTS_PAYLOAD_ROOT" \
    --scripts "$RUNTIME_SCRIPT_DIR" \
    --identifier "$RUNTIME_PKG_ID" \
    --version "$APP_VERSION" \
    --install-location "/" \
    --sign "$PKG_SIGN_IDENTITY" \
    "$RUNTIME_COMPONENT_PKG"
else
  pkgbuild \
    --root "$SCRIPTS_PAYLOAD_ROOT" \
    --scripts "$RUNTIME_SCRIPT_DIR" \
    --identifier "$RUNTIME_PKG_ID" \
    --version "$APP_VERSION" \
    --install-location "/" \
    "$RUNTIME_COMPONENT_PKG"
fi

get_pkg_identifier() {
  local pkg_path="$1"
  local tmp_dir
  tmp_dir="$(mktemp -d "$BUILD_DIR/.pkgexpand.XXXXXX")"

  if ! pkgutil --expand-full "$pkg_path" "$tmp_dir" >/dev/null 2>&1; then
    pkgutil --expand "$pkg_path" "$tmp_dir" >/dev/null 2>&1
  fi

  local info_file="$tmp_dir/PackageInfo"
  local pkg_id=""
  if [[ -f "$info_file" ]]; then
    pkg_id="$(/usr/bin/xmllint --xpath 'string(/pkg-info/@identifier)' "$info_file" 2>/dev/null || true)"
  else
    local nested
    nested="$(find "$tmp_dir" -name PackageInfo | head -n 1 || true)"
    if [[ -n "$nested" ]]; then
      pkg_id="$(/usr/bin/xmllint --xpath 'string(/pkg-info/@identifier)' "$nested" 2>/dev/null || true)"
    fi
  fi

  rm -rf "$tmp_dir"
  if [[ -z "$pkg_id" ]]; then
    pkg_id="$(basename "$pkg_path" .pkg)"
  fi
  echo "$pkg_id"
}

DEP_PKGS=()
while IFS= read -r dep_pkg; do
  DEP_PKGS+=("$dep_pkg")
done < <(find "$DEPS_DIR" -maxdepth 1 -type f -name "*.pkg" | sort)

echo "==> Generating Distribution.xml"
{
  echo '<?xml version="1.0" encoding="utf-8"?>'
  echo '<installer-gui-script minSpecVersion="2">'
  echo '  <title>Juice</title>'
  echo '  <options customize="never" require-scripts="false"/>'
  echo '  <domains enable_anywhere="false" enable_currentUserHome="false" enable_localSystem="true"/>'
  echo '  <volume-check>'
  echo '    <allowed-os-versions>'
  echo "      <os-version min=\"$MIN_OS_VERSION\"/>"
  echo '    </allowed-os-versions>'
  echo '  </volume-check>'
  echo '  <choices-outline>'
  echo '    <line choice="default">'
  echo '      <line choice="juice.app"/>'
  echo '      <line choice="juice.runtime"/>'
  if [[ ${#DEP_PKGS[@]} -gt 0 ]]; then
    for dep_pkg in "${DEP_PKGS[@]}"; do
      dep_base="$(basename "$dep_pkg" .pkg)"
      echo "      <line choice=\"dep.$dep_base\"/>"
    done
  fi
  echo '    </line>'
  echo '  </choices-outline>'
  echo '  <choice id="default" visible="false" title="Juice"/>'
  echo '  <choice id="juice.app" visible="false" title="Juice App">'
  echo "    <pkg-ref id=\"$APP_PKG_ID\"/>"
  echo '  </choice>'
  echo '  <choice id="juice.runtime" visible="false" title="Juice Runtime">'
  echo "    <pkg-ref id=\"$RUNTIME_PKG_ID\"/>"
  echo '  </choice>'

  if [[ ${#DEP_PKGS[@]} -gt 0 ]]; then
    for dep_pkg in "${DEP_PKGS[@]}"; do
      dep_file="$(basename "$dep_pkg")"
      dep_base="$(basename "$dep_pkg" .pkg)"
      dep_id="$(get_pkg_identifier "$dep_pkg")"
      echo "  <choice id=\"dep.$dep_base\" visible=\"false\" title=\"$dep_base\">"
      echo "    <pkg-ref id=\"$dep_id\"/>"
      echo '  </choice>'
    done
  fi

  echo "  <pkg-ref id=\"$APP_PKG_ID\" version=\"$APP_VERSION\">$(basename "$APP_COMPONENT_PKG")</pkg-ref>"
  echo "  <pkg-ref id=\"$RUNTIME_PKG_ID\" version=\"$APP_VERSION\">$(basename "$RUNTIME_COMPONENT_PKG")</pkg-ref>"

  if [[ ${#DEP_PKGS[@]} -gt 0 ]]; then
    for dep_pkg in "${DEP_PKGS[@]}"; do
      dep_file="$(basename "$dep_pkg")"
      dep_id="$(get_pkg_identifier "$dep_pkg")"
      echo "  <pkg-ref id=\"$dep_id\">$dep_file</pkg-ref>"
    done
  fi

  echo '</installer-gui-script>'
} > "$DIST_XML"

echo "==> Building product package"
if [[ "$UNSIGNED" != "1" ]]; then
  productbuild \
    --distribution "$DIST_XML" \
    --resources "$RESOURCES_DIR" \
    --package-path "$BUILD_DIR" \
    --package-path "$DEPS_DIR" \
    --sign "$PKG_SIGN_IDENTITY" \
    "$PRODUCT_PKG"
else
  productbuild \
    --distribution "$DIST_XML" \
    --resources "$RESOURCES_DIR" \
    --package-path "$BUILD_DIR" \
    --package-path "$DEPS_DIR" \
    "$PRODUCT_PKG"
fi

echo "==> Verifying package signature"
if ! pkgutil --check-signature "$PRODUCT_PKG"; then
  echo "warning: pkg signature check failed"
fi

echo "==> Running Gatekeeper installer assessment"
if ! spctl --assess --type install -vv "$PRODUCT_PKG"; then
  echo "warning: spctl assessment failed (expected on some unsigned/unnotarized builds)"
fi

if [[ "$NOTARIZE" == "1" ]]; then
  if [[ -z "$NOTARY_PROFILE" ]]; then
    echo "error: NOTARIZE=1 requires NOTARY_PROFILE=<keychain-profile-name>" >&2
    exit 1
  fi
  echo "==> Submitting installer for notarization"
  xcrun notarytool submit "$PRODUCT_PKG" --keychain-profile "$NOTARY_PROFILE" --wait
  echo "==> Stapling notarization ticket"
  xcrun stapler staple "$PRODUCT_PKG"
fi

echo "==> Done"
echo "$PRODUCT_PKG"
