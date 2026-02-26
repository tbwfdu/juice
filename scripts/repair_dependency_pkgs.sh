#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_DEPS_DIR="$ROOT_DIR/installer/deps"
TARGET="${1:-$DEFAULT_DEPS_DIR}"
INPLACE="${INPLACE:-0}"
APP_SIGN_IDENTITY="${APP_SIGN_IDENTITY:-}"
PKG_SIGN_IDENTITY="${PKG_SIGN_IDENTITY:-}"

usage() {
  cat <<USAGE
Usage:
  APP_SIGN_IDENTITY="Developer ID Application: ..." \\
  PKG_SIGN_IDENTITY="Developer ID Installer: ..." \\
  ./scripts/repair_dependency_pkgs.sh [pkg-or-dir]

Options via env:
  INPLACE=1   Replace original pkg(s) with repaired signed pkg(s).

Notes:
  - Re-signs every Mach-O found in payload with secure timestamp.
  - Repackages and signs repaired pkg with Developer ID Installer cert.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ -z "$APP_SIGN_IDENTITY" || -z "$PKG_SIGN_IDENTITY" ]]; then
  echo "error: APP_SIGN_IDENTITY and PKG_SIGN_IDENTITY are required." >&2
  usage
  exit 2
fi

if [[ ! -e "$TARGET" ]]; then
  echo "error: target not found: $TARGET" >&2
  exit 2
fi

PKGS=()
if [[ -d "$TARGET" ]]; then
  while IFS= read -r pkg; do
    PKGS+=("$pkg")
  done < <(find "$TARGET" -maxdepth 1 -type f -name "*.pkg" | sort)
else
  case "$TARGET" in
    *.pkg) PKGS+=("$TARGET") ;;
    *)
      echo "error: target must be .pkg or directory" >&2
      exit 2
      ;;
  esac
fi

if [[ ${#PKGS[@]} -eq 0 ]]; then
  echo "No pkg files found."
  exit 0
fi

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/juice-repairpkgs.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

extract_payload_if_needed() {
  local component_dir="$1"
  local payload_file="$component_dir/Payload"
  local payload_dir="$component_dir/Payload"

  if [[ -d "$payload_dir" ]]; then
    echo "$payload_dir"
    return 0
  fi

  if [[ ! -f "$payload_file" ]]; then
    return 1
  fi

  local out_dir="$component_dir/.payload-expanded"
  mkdir -p "$out_dir"

  local ftype
  ftype="$(file -b "$payload_file" 2>/dev/null || true)"

  if echo "$ftype" | grep -qi "gzip compressed"; then
    gzip -dc "$payload_file" | (cd "$out_dir" && cpio -idm --quiet)
    echo "$out_dir"
    return 0
  fi
  if echo "$ftype" | grep -qi "XZ compressed" && command -v xz >/dev/null 2>&1; then
    xz -dc "$payload_file" | (cd "$out_dir" && cpio -idm --quiet)
    echo "$out_dir"
    return 0
  fi
  if echo "$ftype" | grep -qi "bzip2 compressed" && command -v bzip2 >/dev/null 2>&1; then
    bzip2 -dc "$payload_file" | (cd "$out_dir" && cpio -idm --quiet)
    echo "$out_dir"
    return 0
  fi

  cat "$payload_file" | (cd "$out_dir" && cpio -idm --quiet) >/dev/null 2>&1 || return 1
  echo "$out_dir"
}

sign_macho_file() {
  local path="$1"
  # --options runtime is applied to ensure modern notarization-compatible signatures.
  codesign --force --timestamp --options runtime --sign "$APP_SIGN_IDENTITY" "$path"
}

for pkg in "${PKGS[@]}"; do
  echo ""
  echo "==> Repairing $(basename "$pkg")"

  WORK_DIR="$TMP_ROOT/$(basename "$pkg" .pkg)"
  EXPANDED_DIR="$WORK_DIR/expanded"
  mkdir -p "$WORK_DIR"

  if ! pkgutil --expand-full "$pkg" "$EXPANDED_DIR" >/dev/null 2>&1; then
    rm -rf "$EXPANDED_DIR"
    pkgutil --expand "$pkg" "$EXPANDED_DIR"
  fi

  COMPONENTS=()
  while IFS= read -r info; do
    COMPONENTS+=("${info%/PackageInfo}")
  done < <(find "$EXPANDED_DIR" -name PackageInfo -print)

  if [[ ${#COMPONENTS[@]} -eq 0 && ( -f "$EXPANDED_DIR/Payload" || -d "$EXPANDED_DIR/Payload" ) ]]; then
    COMPONENTS+=("$EXPANDED_DIR")
  fi

  if [[ ${#COMPONENTS[@]} -eq 0 ]]; then
    echo "  warning: no components found, skipping"
    continue
  fi

  total_signed=0
  for comp in "${COMPONENTS[@]}"; do
    payload_root="$(extract_payload_if_needed "$comp" || true)"
    if [[ -z "$payload_root" || ! -d "$payload_root" ]]; then
      echo "  warning: no payload root found for component $comp"
      continue
    fi

    while IFS= read -r f; do
      if ! file -b "$f" | grep -q "Mach-O"; then
        continue
      fi
      sign_macho_file "$f"
      total_signed=$((total_signed + 1))
    done < <(find "$payload_root" -type f)

    # Re-sign bundle containers after internal binaries are signed.
    while IFS= read -r appb; do
      codesign --force --deep --timestamp --options runtime --sign "$APP_SIGN_IDENTITY" "$appb"
    done < <(find "$payload_root" -type d -name "*.app")

    while IFS= read -r fw; do
      codesign --force --deep --timestamp --options runtime --sign "$APP_SIGN_IDENTITY" "$fw"
    done < <(find "$payload_root" -type d -name "*.framework")
  done

  echo "  signed Mach-O files: $total_signed"

  base_name="$(basename "$pkg" .pkg)"
  unsigned_repacked="$WORK_DIR/${base_name}.repacked.pkg"
  repaired_signed="$WORK_DIR/${base_name}.repaired-signed.pkg"

  pkgutil --flatten-full "$EXPANDED_DIR" "$unsigned_repacked"
  productsign --sign "$PKG_SIGN_IDENTITY" "$unsigned_repacked" "$repaired_signed"

  pkgutil --check-signature "$repaired_signed" >/dev/null || true

  if [[ "$INPLACE" == "1" ]]; then
    cp -f "$repaired_signed" "$pkg"
    echo "  replaced original: $pkg"
  else
    out_dir="$(dirname "$pkg")"
    out_pkg="$out_dir/${base_name}.repaired-signed.pkg"
    cp -f "$repaired_signed" "$out_pkg"
    echo "  wrote: $out_pkg"
  fi

done

echo ""
echo "Repair complete."
