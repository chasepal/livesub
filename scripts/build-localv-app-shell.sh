#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE="$ROOT/mac/Packages/LocalVAppShell"
BUILD_DIR="$ROOT/build"
APP_NAME="${LIVESUB_APP_NAME:-LiveSub}"
APP="$ROOT/build/$APP_NAME.app"
APP_ARCHIVE_DIR="$ROOT/build/apps"
RELEASE_DIR="$ROOT/build/releases"
BUILD_STATE="$ROOT/build/.livesub-build-number"
RELEASE_VERSION="${LIVESUB_VERSION:-0.2.1-alpha}"
PLIST_VERSION="${LIVESUB_PLIST_VERSION:-0.2.1}"
CONFIGURATION="${LIVESUB_CONFIGURATION:-release}"
APPLICATIONS_DIR="${LIVESUB_APPLICATIONS_DIR:-/Applications}"
APPLICATIONS_APP="$APPLICATIONS_DIR/$APP_NAME.app"
APPLICATIONS_VERSIONED_APP="$APPLICATIONS_DIR/$APP_NAME-$RELEASE_VERSION.app"

mkdir -p "$BUILD_DIR"
if [[ -f "$BUILD_STATE" ]] && [[ "$(cat "$BUILD_STATE")" =~ ^[0-9]+$ ]]; then
  BUILD_NUMBER="$(cat "$BUILD_STATE")"
else
  BUILD_NUMBER="0"
fi
BUILD_NUMBER="$((BUILD_NUMBER + 1))"
VERSIONED_APP="$APP_ARCHIVE_DIR/$APP_NAME-$RELEASE_VERSION.app"
RELEASE_ZIP="$RELEASE_DIR/$APP_NAME-v$RELEASE_VERSION-macos.zip"

swift build --package-path "$PACKAGE" -c "$CONFIGURATION"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$PACKAGE/.build/$CONFIGURATION/LocalVAppShell" "$APP/Contents/MacOS/LocalVAppShell"
cp "$PACKAGE/Info.plist" "$APP/Contents/Info.plist"
cp "$PACKAGE/Resources/LiveSub.icns" "$APP/Contents/Resources/LiveSub.icns"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $PLIST_VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP/Contents/Info.plist"

codesign --force --deep --sign - "$APP"

mkdir -p "$APP_ARCHIVE_DIR" "$RELEASE_DIR"
rm -rf "$VERSIONED_APP"
ditto "$APP" "$VERSIONED_APP"
rm -f "$RELEASE_ZIP"
ditto -c -k --keepParent --norsrc --noextattr "$APP" "$RELEASE_ZIP"

if [[ -d "$APPLICATIONS_DIR" && -w "$APPLICATIONS_DIR" ]]; then
  rm -rf "$APPLICATIONS_APP"
  rm -rf "$APPLICATIONS_VERSIONED_APP"
  ditto "$APP" "$APPLICATIONS_APP"
  ditto "$VERSIONED_APP" "$APPLICATIONS_VERSIONED_APP"
  APPLICATIONS_RESULT="$APPLICATIONS_APP, $APPLICATIONS_VERSIONED_APP"
else
  APPLICATIONS_RESULT="skipped: $APPLICATIONS_DIR is not writable"
fi

printf "%s\n" "$BUILD_NUMBER" > "$BUILD_STATE"

echo "Version: $RELEASE_VERSION"
echo "Bundle version: $BUILD_NUMBER"
echo "Configuration: $CONFIGURATION"
echo "Build app: $APP"
echo "Versioned app: $VERSIONED_APP"
echo "Release zip: $RELEASE_ZIP"
echo "Applications app: $APPLICATIONS_RESULT"
