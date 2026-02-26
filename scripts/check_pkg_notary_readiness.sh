#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_TARGET="$ROOT_DIR/installer/deps"

TARGET="${1:-$DEFAULT_TARGET}"

usage() {
  cat <<USAGE
Usage:
  ./scripts/check_pkg_notary_readiness.sh [pkg-or-dir]

Behavior:
  - If target is a directory, scans all *.pkg files in it.
  - If target is a single .pkg file, scans that package only.
  - Expands packages and inspects Mach-O files for:
      * missing code signature
      * missing secure timestamp ("Timestamp=" not present in codesign details)

Exit codes:
  0 = no issues found
  1 = one or more issues found
  2 = usage or tool error
USAGE
}

need_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: required tool not found: $1" >&2
    exit 2
  fi
}

need_tool pkgutil
need_tool codesign
need_tool file
need_tool cpio
need_tool gzip

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ ! -e "$TARGET" ]]; then
  echo "error: target does not exist: $TARGET" >&2
  usage
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
      echo "error: target must be a .pkg file or directory containing .pkg files" >&2
      exit 2
      ;;
  esac
fi

if [[ ${#PKGS[@]} -eq 0 ]]; then
  echo "No .pkg files found in $TARGET"
  exit 0
fi

extract_payload() {
  local payload_file="$1"
  local out_dir="$2"
  local ftype
  ftype="$(file -b "$payload_file" 2>/dev/null || true)"

  if echo "$ftype" | grep -qi "gzip compressed"; then
    gzip -dc "$payload_file" | (cd "$out_dir" && cpio -idm --quiet)
    return 0
  fi
  if echo "$ftype" | grep -qi "XZ compressed"; then
    if command -v xz >/dev/null 2>&1; then
      xz -dc "$payload_file" | (cd "$out_dir" && cpio -idm --quiet)
      return 0
    fi
    return 1
  fi
  if echo "$ftype" | grep -qi "bzip2 compressed"; then
    if command -v bzip2 >/dev/null 2>&1; then
      bzip2 -dc "$payload_file" | (cd "$out_dir" && cpio -idm --quiet)
      return 0
    fi
    return 1
  fi

  # Fallback for uncompressed cpio payloads.
  cat "$payload_file" | (cd "$out_dir" && cpio -idm --quiet) >/dev/null 2>&1 || return 1
  return 0
}

ISSUES=0
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/juice-pkgcheck.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

echo "Scanning ${#PKGS[@]} package(s)..."

for pkg in "${PKGS[@]}"; do
  echo ""
  echo "==> $pkg"

  if ! pkgutil --check-signature "$pkg" >/dev/null 2>&1; then
    echo "  [warn] Package signature check failed"
  fi

  PKG_TMP="$TMP_ROOT/$(basename "$pkg" .pkg)"
  mkdir -p "$PKG_TMP"
  EXPANDED_DIR="$PKG_TMP/expanded"
  rm -rf "$EXPANDED_DIR"

  if ! pkgutil --expand-full "$pkg" "$EXPANDED_DIR" >/dev/null 2>&1; then
    rm -rf "$EXPANDED_DIR"
    if ! pkgutil --expand "$pkg" "$EXPANDED_DIR" >/dev/null 2>&1; then
      echo "  [error] Could not expand package"
      ISSUES=1
      continue
    fi
  fi

  COMPONENT_ROOTS=()
  while IFS= read -r p; do
    COMPONENT_ROOTS+=("$p")
  done < <(find "$EXPANDED_DIR" -name PackageInfo -print | sed 's#/PackageInfo$##')

  if [[ ${#COMPONENT_ROOTS[@]} -eq 0 && ( -f "$EXPANDED_DIR/Payload" || -d "$EXPANDED_DIR/Payload" ) ]]; then
    COMPONENT_ROOTS+=("$EXPANDED_DIR")
  fi

  if [[ ${#COMPONENT_ROOTS[@]} -eq 0 ]]; then
    echo "  [warn] No component payloads found"
    continue
  fi

  for comp in "${COMPONENT_ROOTS[@]}"; do
    PAYLOAD_TMP=""
    if [[ -d "$comp/Payload" ]]; then
      PAYLOAD_TMP="$comp/Payload"
    elif [[ -f "$comp/Payload" ]]; then
      payload_file="$comp/Payload"
      PAYLOAD_TMP="$comp/.payload-expanded"
      mkdir -p "$PAYLOAD_TMP"
      if ! extract_payload "$payload_file" "$PAYLOAD_TMP"; then
        echo "  [warn] Could not decode payload: $payload_file"
        continue
      fi
    else
      continue
    fi

    while IFS= read -r bin; do
      if ! file -b "$bin" | grep -q "Mach-O"; then
        continue
      fi

      SIGN_DETAILS="$(codesign -dv --verbose=4 "$bin" 2>&1 || true)"
      if ! echo "$SIGN_DETAILS" | grep -q "Authority="; then
        echo "  [error] Unsigned Mach-O: ${bin#$PAYLOAD_TMP/}"
        ISSUES=1
        continue
      fi

      if ! echo "$SIGN_DETAILS" | grep -q "Timestamp="; then
        echo "  [error] Missing secure timestamp: ${bin#$PAYLOAD_TMP/}"
        ISSUES=1
      fi
    done < <(find "$PAYLOAD_TMP" -type f)
  done
done

echo ""
if [[ "$ISSUES" -eq 0 ]]; then
  echo "No notarization readiness issues found."
  exit 0
fi

echo "Notarization readiness issues were found."
exit 1
