#!/bin/bash
# Replace only BuildMachineOSBuild when it is a macOS 27 seed (26A…).
# Do not touch DTSDKBuild / DTPlatformBuild — 23F81a is the Xcode 26.6 GM iOS SDK.
set -euo pipefail

ROOT="${1:?path to .app}"
MACOS_GA="25G83"

while IFS= read -r -d '' plist; do
  if /usr/bin/plutil -extract BuildMachineOSBuild raw "$plist" >/dev/null 2>&1; then
    current=$(/usr/bin/plutil -extract BuildMachineOSBuild raw "$plist")
    echo "  $plist BuildMachineOSBuild=$current"
    if [[ "$current" == 26A* ]]; then
      /usr/bin/plutil -replace BuildMachineOSBuild -string "$MACOS_GA" "$plist"
      echo "    -> $MACOS_GA"
    fi
  fi
done < <(find "$ROOT" -name Info.plist -print0)
