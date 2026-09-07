#!/bin/bash
# Archive Wink One for the App Store.
#
# NOTE: this script deliberately does NOT rewrite BuildMachineOSBuild or any
# other DT*/BuildMachine stamp. Those fields record the real toolchain and host
# OS, and Apple checks them. Rewriting them to hide a beta build host is a
# review-rules violation and produced repeated "Invalid Binary" results.
# If Apple rejects a build for beta software, the fix is to build on a release
# macOS, not to edit the plist.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

BUILD="${1:?usage: archive_and_upload.sh <build-number>}"
ARCHIVE="$HOME/Desktop/WinkOne_Build${BUILD}.xcarchive"
EXPORT="$HOME/Desktop/WinkOne_Build${BUILD}_ipa"

echo "=== Toolchain ==="
xcodebuild -version
sw_vers

echo "=== Clean ==="
rm -rf "$ARCHIVE" "$EXPORT"
xcodebuild clean -project "$ROOT/WinkOne.xcodeproj" -scheme WinkOne -configuration Release

echo "=== Archive ==="
xcodebuild archive \
  -project "$ROOT/WinkOne.xcodeproj" \
  -scheme WinkOne \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE" \
  -sdk iphoneos \
  -allowProvisioningUpdates \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM=N73XW3H4MX

APP="$ARCHIVE/Products/Applications/WinkOne.app"
echo "=== Stamps as built ==="
plutil -p "$APP/Info.plist" | grep -E "BuildMachine|DTPlatform|DTSDK|DTXcode|MinimumOS|CFBundleVersion"

echo "=== Export .ipa ==="
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$ROOT/ExportOptionsExport.plist" \
  -exportPath "$EXPORT" \
  -allowProvisioningUpdates

echo "=== Done. Upload $EXPORT/*.ipa with Transporter. ==="
