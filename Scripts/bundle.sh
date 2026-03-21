#!/usr/bin/env bash
set -euo pipefail

# bundle.sh: Package the built ManoScroll binary into a macOS .app bundle

APP_NAME="ManoScrollApp"
BUNDLE_NAME="ManoScroll"
# Detect bin path from swift build
BIN_PATH=$(xcrun swift build -c release --show-bin-path)
BUILD_DIR="${BIN_PATH}"
BUNDLE_DIR="${BUNDLE_NAME}.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "Creating app bundle structure..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Copy executable
cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"

# Copy Info.plist
cp ManoScrollApp/Info.plist "$CONTENTS_DIR/Info.plist"

# Determine version
VERSION="${APP_VERSION:-1.0.0}"
if [[ -z "${APP_VERSION:-}" && -f "VERSION" ]]; then
    VERSION=$(tr -d '[:space:]' < VERSION)
fi

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "${CONTENTS_DIR}/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "${CONTENTS_DIR}/Info.plist"

# Copy app icon
if [[ -f "AppIcon.icns" ]]; then
    cp AppIcon.icns "$RESOURCES_DIR/AppIcon.icns"
fi

# Create PkgInfo
echo "APPL????" > "$CONTENTS_DIR/PkgInfo"

# Ad-hoc sign for local use
codesign --force --deep --verify --verbose --options runtime --entitlements "ManoScrollApp/ManoScrollApp.entitlements" --sign "-" "$BUNDLE_DIR" 2>/dev/null || echo "Warning: Ad-hoc signing failed"

echo "✓ Build complete: $BUNDLE_DIR"
