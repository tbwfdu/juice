#!/usr/bin/env bash
set -euo pipefail

REMOVE_MUNKI=0
ALL_USERS=0
ASSUME_YES=0

usage() {
  cat <<USAGE
Usage:
  ./scripts/uninstall_juice.sh [options]

Options:
  --remove-munki    Also remove /usr/local/munki and forget Munki receipts.
  --all-users       Remove Juice user data from all local user home dirs.
  --yes             Non-interactive mode (skip confirmation prompts).
  -h, --help        Show this help.

Default behavior:
  - Removes /Applications/Juice.app
  - Removes /usr/local/juice
  - Removes current user's ~/.juice and ~/Juice
  - Removes current user's munkiimport preferences file
  - Removes current user's Juice defaults/preferences plist
  - Removes current user's Juice app-group container data
  - Forgets Juice installer receipts
USAGE
}

confirm() {
  local prompt="$1"
  if [[ "$ASSUME_YES" -eq 1 ]]; then
    return 0
  fi
  printf "%s [y/N]: " "$prompt"
  read -r reply
  [[ "$reply" == "y" || "$reply" == "Y" ]]
}

for arg in "$@"; do
  case "$arg" in
    --remove-munki) REMOVE_MUNKI=1 ;;
    --all-users) ALL_USERS=1 ;;
    --yes) ASSUME_YES=1 ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      usage
      exit 2
      ;;
  esac
done

echo "Juice uninstall plan:"
echo "  - Remove /Applications/Juice.app"
echo "  - Remove /usr/local/juice"
if [[ "$ALL_USERS" -eq 1 ]]; then
  echo "  - Remove ~/.juice and ~/Juice for all local users"
  echo "  - Remove munkiimport prefs for all local users"
else
  echo "  - Remove ~/.juice and ~/Juice for current user ($USER)"
  echo "  - Remove munkiimport prefs for current user ($USER)"
fi
echo "  - Forget receipts: com.tbwfdu.juice.app, com.tbwfdu.juice.runtime"
if [[ "$REMOVE_MUNKI" -eq 1 ]]; then
  echo "  - Remove /usr/local/munki and forget all receipts matching 'munki'"
fi

if ! confirm "Proceed with uninstall?"; then
  echo "Cancelled."
  exit 0
fi

echo "Removing /Applications/Juice.app..."
sudo rm -rf /Applications/Juice.app

echo "Removing /usr/local/juice..."
sudo rm -rf /usr/local/juice

if [[ "$ALL_USERS" -eq 1 ]]; then
  echo "Removing Juice data for all local users..."
  while IFS=: read -r username _ uid _ _ home _; do
    if [[ -z "$home" || ! -d "$home" ]]; then
      continue
    fi
    # Skip system users.
    if [[ "$uid" -lt 500 && "$uid" -ne 0 ]]; then
      continue
    fi
    rm -rf "$home/.juice" "$home/Juice"
    rm -f "$home/Library/Preferences/com.googlecode.munki.munkiimport.plist"
  done < /etc/passwd
else
  echo "Removing Juice data for current user..."
  rm -rf "$HOME/.juice" "$HOME/Juice"
  rm -f "$HOME/Library/Preferences/com.googlecode.munki.munkiimport.plist"
  defaults delete com.tbwfdu.juice 2>/dev/null || true
  rm -f "$HOME/Library/Preferences/com.tbwfdu.juice.plist"
  rm -rf "$HOME/Library/Group Containers/group.com.tbwfdu.juice"
fi

echo "Forgetting Juice package receipts..."
sudo pkgutil --forget com.tbwfdu.juice.app >/dev/null 2>&1 || true
sudo pkgutil --forget com.tbwfdu.juice.runtime >/dev/null 2>&1 || true

if [[ "$REMOVE_MUNKI" -eq 1 ]]; then
  if confirm "Also remove /usr/local/munki and forget Munki receipts?"; then
    echo "Removing /usr/local/munki..."
    sudo rm -rf /usr/local/munki

    echo "Forgetting Munki package receipts..."
    while IFS= read -r receipt; do
      sudo pkgutil --forget "$receipt" >/dev/null 2>&1 || true
    done < <(pkgutil --pkgs | grep -i munki || true)
  fi
fi

echo "Uninstall complete."
