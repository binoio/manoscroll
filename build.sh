#!/bin/bash
# Build script for ManoScroll.app

set -e

# Build the executable
echo "Building ManoScrollApp..."
swift build -c release

# Create app bundle structure
APP_DIR="ManoScroll.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "Creating app bundle structure..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable
echo "Copying executable..."
cp .build/release/ManoScrollApp "$MACOS_DIR/ManoScrollApp"

# Copy Info.plist
echo "Copying Info.plist..."
cp ManoScrollApp/Info.plist "$CONTENTS_DIR/Info.plist"

# Copy app icon
echo "Copying app icon..."
cp AppIcon.icns "$RESOURCES_DIR/AppIcon.icns"

# Create PkgInfo
echo "APPL????" > "$CONTENTS_DIR/PkgInfo"

# Sign the app (ad-hoc signing for local use)
echo "Signing app..."
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || echo "Warning: Signing failed, app may need manual signing"

echo ""
echo "Build complete: $APP_DIR"
echo ""
echo "To run the app:"
echo "  open $APP_DIR"
echo ""
echo "Note: You may need to grant camera and accessibility permissions in System Preferences."
