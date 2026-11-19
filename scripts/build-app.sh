#!/usr/bin/env bash
# Builds PerAppVolume.app (universal: Apple Silicon + Intel) and a zip ready for GitHub Releases.
# Usage: ./scripts/build-app.sh            -> build/PerAppVolume.app + build/PerAppVolume-<version>.zip
#        ARCHS=arm64 ./scripts/build-app.sh  -> only one architecture (faster)
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="PerAppVolume"
BUILD_DIR="build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
ARCHS="${ARCHS:-arm64 x86_64}"
MIN_MACOS="14.2"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' AppBundle/Info.plist)"

echo "==> Building $APP_NAME $VERSION for: $ARCHS"
binaries=()
for arch in $ARCHS; do
    triple="$arch-apple-macosx$MIN_MACOS"
    swift build -c release --product "$APP_NAME" --triple "$triple"
    bin_path="$(swift build -c release --product "$APP_NAME" --triple "$triple" --show-bin-path)"
    binaries+=("$bin_path/$APP_NAME")
done

echo "==> Assembling $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
lipo -create "${binaries[@]}" -output "$APP_DIR/Contents/MacOS/$APP_NAME"
cp AppBundle/Info.plist "$APP_DIR/Contents/Info.plist"
cp AppBundle/AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"
cp -R AppBundle/en.lproj AppBundle/es.lproj "$APP_DIR/Contents/Resources/"

echo "==> Signing (ad-hoc)"
codesign --force --deep --sign - "$APP_DIR"
codesign --verify --verbose=1 "$APP_DIR"

echo "==> Packaging"
ZIP="$BUILD_DIR/$APP_NAME-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP"

echo ""
echo "Done:"
echo "  App: $APP_DIR"
echo "  Zip: $ZIP"
lipo -info "$APP_DIR/Contents/MacOS/$APP_NAME"
