#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="Get Shit Done"
BUNDLE_NAME="GetShitDone"
BUILD_DIR=".build"
APP_DIR="$BUILD_DIR/${APP_NAME}.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "Building ${APP_NAME}..."

# Build the executable
swift build -c release 2>&1

EXEC_PATH="$BUILD_DIR/release/$BUNDLE_NAME"

if [ ! -f "$EXEC_PATH" ]; then
    echo "Build failed - executable not found at $EXEC_PATH"
    # Try debug build
    swift build 2>&1
    EXEC_PATH="$BUILD_DIR/debug/$BUNDLE_NAME"
fi

echo "Creating app bundle..."

# Create .app bundle structure
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable
cp "$EXEC_PATH" "$MACOS_DIR/$BUNDLE_NAME"

# Copy Info.plist
cp "$BUNDLE_NAME/Info.plist" "$CONTENTS_DIR/Info.plist"

# Copy app icon
if [ -f "$BUNDLE_NAME/AppIcon.icns" ]; then
    cp "$BUNDLE_NAME/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

# Create PkgInfo
echo -n "APPL????" > "$CONTENTS_DIR/PkgInfo"

# Ad-hoc sign the app
codesign --force --sign - --entitlements "$BUNDLE_NAME/GetShitDone.entitlements" "$APP_DIR" 2>/dev/null || true

echo ""
echo "Build complete!"
echo "App bundle: $APP_DIR"
echo ""
echo "To run:"
echo "  open \"$APP_DIR\""
echo ""
echo "To install:"
echo "  cp -r \"$APP_DIR\" /Applications/"
