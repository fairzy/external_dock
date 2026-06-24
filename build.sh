#!/bin/bash
# build.sh — Build ExternalDock.app from Swift source files
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="ExternalDock"
BUILD_DIR="$PROJECT_DIR/build"

echo "🔨 Building $APP_NAME..."

# Clean
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/$APP_NAME.app/Contents/MacOS"
mkdir -p "$BUILD_DIR/$APP_NAME.app/Contents/Resources"

# Compile - Release build
echo "📝 Compiling Swift sources (RELEASE)..."
swiftc \
    -o "$BUILD_DIR/$APP_NAME.app/Contents/MacOS/$APP_NAME" \
    -target arm64-apple-macos13.0 \
    "$PROJECT_DIR/App/main.swift" \
    "$PROJECT_DIR/App/ExternalDockApp.swift" \
    "$PROJECT_DIR/App/DockWindowManager.swift" \
    "$PROJECT_DIR/App/DockViewController.swift" \
    "$PROJECT_DIR/App/AppIconManager.swift" \
    "$PROJECT_DIR/App/SettingsWindowController.swift" \
    -framework Cocoa \
    -framework AppKit \
    -O \
    -whole-module-optimization

# Copy Info.plist
cp "$PROJECT_DIR/Resources/Info.plist" "$BUILD_DIR/$APP_NAME.app/Contents/"

# Copy icon
cp "$PROJECT_DIR/Resources/ExternalDock.icns" "$BUILD_DIR/$APP_NAME.app/Contents/Resources/"

# Sign the app (ad-hoc signature, makes TCC/Accessibility permission persistent)
codesign --sign - --force --deep "$BUILD_DIR/$APP_NAME.app" 2>/dev/null && \
  echo "🔏 Signed app bundle (ad-hoc)"

# Copy to /Applications (optional)
# cp -R "$BUILD_DIR/$APP_NAME.app" "/Applications/$APP_NAME.app" 2>/dev/null || true

echo ""
echo "✅ Build complete!"
echo "   App bundle: $BUILD_DIR/$APP_NAME.app"
echo ""
echo "   Run it: open \"$BUILD_DIR/$APP_NAME.app\""
echo "   Or copy to Applications:"
echo "     cp -R \"$BUILD_DIR/$APP_NAME.app\" /Applications/"