#!/usr/bin/env bash

# --------------------------
# Developer Account Details:
# For the very first time running this, you can generate the Developer ID Installer and Developer ID Application
# from certificates in Xcode.
#
# Then: security find-identity -v -p basic | grep "Developer ID"
#
# Developer ID Installer: Peter Lindley (ZV33P8H324)
# Developer ID Application: Peter Lindley (ZV33P8H324)
# --------------------------

# --------------------------
# Generate a App Password for Apple ID, called juice-notarize
# Sign in → Sign-In and Security → App-Specific Passwords → generate one
# Use that generated string (format like abcd-efgh-ijkl-mnop) as --password
# Team ID: ZV33P8H324
#
# To save it,
# xcrun notarytool store-credentials "juice-notary" \
#  --apple-id "thisispete@gmail.com" \
#  --team-id "ZV33P8H324" \
#  --password "ysfr-nxpt-oknj-zwah"
# -------------------------


# --------------------------
# Build
# --------------------------

PKG_SIGN_IDENTITY="Developer ID Installer: Peter Lindley (ZV33P8H324)" \
APP_SIGN_IDENTITY="Developer ID Application: Peter Lindley (ZV33P8H324)" \
./scripts/build_pkg.sh


# --------------------------
# Notarize
# --------------------------

NOTARY_PROFILE="juice-notary" ./scripts/notarize_pkg.sh 