#!/usr/bin/env bash
# Build a native device app on macOS. No signing credentials are used.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "The iPhone SDK build requires macOS/Xcode. Run this through GitHub Actions." >&2
  exit 1
fi
xcrun --find xcodebuild >/dev/null
swift test --package-path iOS
DERIVED="$ROOT/build/iphoneos"
xcodebuild \
  -project iOS/MySnake.xcodeproj \
  -scheme MySnake \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build
APP="$DERIVED/Build/Products/Release-iphoneos/MySnake.app"
test -d "$APP"
test -f "$APP/Info.plist"
/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP/Info.plist"
xcrun lipo -info "$APP/MySnake"
STAGING="$(mktemp -d "$ROOT/build/package.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
mkdir -p "$STAGING/Payload" "$ROOT/dist"
ditto "$APP" "$STAGING/Payload/MySnake.app"
# Required IPA structure is Payload/AppName.app, not an outer wrapper directory.
(cd "$STAGING" && ditto -c -k --keepParent Payload "$ROOT/dist/MySnake-unsigned.ipa")
unzip -Z1 dist/MySnake-unsigned.ipa > "$STAGING/entries.txt"
grep -qx 'Payload/MySnake.app/Info.plist' "$STAGING/entries.txt"
cp docs/INSTALL-WINDOWS.md dist/INSTALL-WINDOWS.md
{
  printf 'My Snake - unsigned native iPhone build\n'
  printf 'Commit: %s\n' "${GITHUB_SHA:-local}"
  printf 'Built (UTC): %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  xcodebuild -version
  printf '\nSigning disabled. This IPA cannot be installed by tapping it in Safari.\n'
} > dist/BUILD-INFO.txt
(cd dist && shasum -a 256 MySnake-unsigned.ipa > SHA256SUMS.txt)
echo 'Created dist/MySnake-unsigned.ipa. Sign it for your own iPhone to install.'
