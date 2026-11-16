#!/bin/bash
# Compile-check only. No account access, signing, upload, or installation.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This check requires a Mac with Xcode. The engine tests alone use: swift test" >&2
  exit 1
fi
if ! xcrun --find xcodebuild >/dev/null 2>&1; then
  echo "Install Xcode and select it in Xcode > Settings > Locations first." >&2
  exit 1
fi
swift test
xcodebuild \
  -project MySnake.xcodeproj \
  -scheme MySnake \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
printf '\nNative Simulator build passed. Use Xcode with your signing team to install on iPhone.\n'
