#!/bin/bash
set -e

DEVICE_UDID="00008130-00141C223E43001C"      # For xcodebuild (iPhone)
DEVICE_UUID="41101104-96E6-58AB-AD27-616A0BFAEF50"  # For devicectl (iPhone)
PROJECT="GifKeyboard.xcodeproj"
CONFIG="Debug"
TEAM_ID="SQ7Z33XY27"

# Clean cached builds
echo "Cleaning cached builds..."
xcodebuild -project "$PROJECT" -scheme "GifKeyboard" -configuration "$CONFIG" clean 2>/dev/null || true
rm -rf ~/Library/Developer/Xcode/DerivedData/GifKeyboard-*

# Build iOS app
echo "Building GifKeyboard (iOS)..."
xcodebuild -project "$PROJECT" -scheme "GifKeyboard" -destination "id=$DEVICE_UDID" -configuration "$CONFIG" DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates build

# Find built app
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/GifKeyboard-*/Build/Products/Debug-iphoneos -name "GifKeyboard.app" -type d 2>/dev/null | head -1)

if [ -z "$APP_PATH" ]; then
    echo "Error: Could not find built iOS app"
    exit 1
fi

echo ""
echo "Found iOS app at: $APP_PATH"

echo ""
echo "Installing iOS app to device..."

# Try devicectl first (Xcode 15+), fall back to ios-deploy
if xcrun devicectl device install app --device "$DEVICE_UUID" "$APP_PATH" 2>/dev/null; then
    echo "iOS app installed successfully via devicectl"

    echo ""
    echo "Launching iOS app..."
    xcrun devicectl device process launch --device "$DEVICE_UUID" com.extroverteddeveloper.GifKeyboard
else
    echo "devicectl failed, trying ios-deploy..."
    ios-deploy -b "$APP_PATH"
fi

echo ""
echo "Done! Now:"
echo "1. Open Files app on iPhone and create 'GifKeyboard' folder in iCloud Drive"
echo "2. Add some GIF files to that folder"
echo "3. Open GifKeyboard app to run initial sync"
echo "4. Go to Settings > General > Keyboard > Keyboards > Add New Keyboard > GifKeyboard"
echo "5. Open any app and switch to GifKeyboard to use it!"
