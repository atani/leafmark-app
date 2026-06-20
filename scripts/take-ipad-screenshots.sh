#!/bin/bash
# Take iPad 13-inch screenshots for App Store submission.
#
# Prerequisites:
#   - Xcode with iPad Pro 13-inch simulator installed
#   - App built for simulator (xcodegen generate && xcodebuild ... -destination 'platform=iOS Simulator')
#   - Peter and Wendy EPUB in repo root for demo content
#
# Usage:
#   ./scripts/take-ipad-screenshots.sh [scheme]
#
# Output: docs/screenshots/ipad-13/ directory with numbered PNGs

set -euo pipefail

SCHEME="${1:-Inkwell}"
SS_DIR="docs/screenshots/ipad-13"
BUNDLE_ID="com.atani.inkwell"
EPUB_FILE="$(ls *.epub 2>/dev/null | head -1)"

mkdir -p "$SS_DIR"

# Find iPad Pro 13-inch simulator
IPAD_ID=$(xcrun simctl list devices available | grep -i "iPad Pro.*13" | head -1 | grep -oE '[A-F0-9-]{36}')
if [ -z "$IPAD_ID" ]; then
    echo "ERROR: iPad Pro 13-inch simulator not found. Install it from Xcode > Settings > Platforms."
    exit 1
fi

echo "Using iPad simulator: $IPAD_ID"

# Boot simulator
xcrun simctl boot "$IPAD_ID" 2>/dev/null || true

# Clean status bar for store screenshots
xcrun simctl status_bar "$IPAD_ID" override \
    --time "9:41" \
    --batteryState charged \
    --batteryLevel 100 \
    --wifiBars 3 \
    --cellularBars 4

# Build for simulator
if [ -f "project.yml" ]; then
    xcodegen generate 2>/dev/null
fi

echo "Building for iPad simulator..."
xcodebuild build \
    -project *.xcodeproj \
    -scheme "$SCHEME" \
    -destination "id=$IPAD_ID" \
    CODE_SIGNING_ALLOWED=NO \
    -quiet

# Install app
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "*.app" -path "*$SCHEME*" -type d | head -1)
if [ -z "$APP_PATH" ]; then
    echo "ERROR: Built app not found. Check the scheme name."
    exit 1
fi
xcrun simctl install "$IPAD_ID" "$APP_PATH"

# Copy demo EPUB into app container
if [ -n "$EPUB_FILE" ]; then
    CONTAINER=$(xcrun simctl get_app_container "$IPAD_ID" "$BUNDLE_ID" data)
    mkdir -p "$CONTAINER/Documents"
    cp "$EPUB_FILE" "$CONTAINER/Documents/"
fi

# Launch app
xcrun simctl launch "$IPAD_ID" "$BUNDLE_ID"
sleep 4

# Take screenshots
echo "Taking screenshots..."
xcrun simctl io "$IPAD_ID" screenshot "$SS_DIR/01-library.png"
echo "  01-library.png"

# Remaining screenshots require manual tab navigation or AppleScript automation.
# The script captures the library view; navigate manually in Simulator for other screens,
# then run:
#   xcrun simctl io "$IPAD_ID" screenshot "$SS_DIR/02-reader.png"
#   xcrun simctl io "$IPAD_ID" screenshot "$SS_DIR/03-highlights.png"
# etc.

echo ""
echo "First screenshot saved to $SS_DIR/01-library.png"
echo "Navigate to other screens in Simulator and run:"
echo "  xcrun simctl io $IPAD_ID screenshot $SS_DIR/0N-name.png"
echo ""

# Clean up status bar
xcrun simctl status_bar "$IPAD_ID" clear

echo "Done. Screenshots in $SS_DIR/"
