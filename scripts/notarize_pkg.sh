#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"

NOTARY_PROFILE="${NOTARY_PROFILE:-}"
PKG_PATH="${1:-}"

usage() {
  cat <<USAGE
Usage:
  ./scripts/notarize_pkg.sh [path/to/installer.pkg]

Environment:
  NOTARY_PROFILE   Required. Keychain profile name configured for notarytool.

Behavior:
  - If no pkg path is provided, the script picks the newest Juice-Installer-*.pkg in ./dist.
  - Submits pkg with notarytool and waits for completion.
  - Staples notarization ticket.
  - Runs spctl installer assessment.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ -z "$NOTARY_PROFILE" ]]; then
  echo "error: NOTARY_PROFILE is required." >&2
  usage
  exit 1
fi

if [[ -z "$PKG_PATH" ]]; then
  PKG_PATH="$(ls -1t "$DIST_DIR"/Juice-Installer-*.pkg 2>/dev/null | head -n 1 || true)"
fi

if [[ -z "$PKG_PATH" ]]; then
  echo "error: no installer package found. Build one first with ./scripts/build_pkg.sh" >&2
  exit 1
fi

if [[ ! -f "$PKG_PATH" ]]; then
  echo "error: package not found at $PKG_PATH" >&2
  exit 1
fi

echo "==> Notarizing: $PKG_PATH"
xcrun notarytool submit "$PKG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling notarization ticket"
xcrun stapler staple "$PKG_PATH"

echo "==> Gatekeeper assessment"
spctl --assess --type install -vv "$PKG_PATH"

echo "==> Done"
echo "$PKG_PATH"
