#!/bin/bash
set -e

PROJECT="GifKeyboard.xcodeproj"
SCHEME="GifKeyboard"
SIMULATOR="iPhone 17 Pro"

# Check if xcpretty is available
if command -v xcpretty &> /dev/null; then
    FORMATTER="xcpretty"
else
    FORMATTER="cat"
fi

echo "Building GifKeyboard for iOS Simulator..."
xcodebuild build \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,name=$SIMULATOR,OS=latest" \
  2>&1 | $FORMATTER

echo ""
echo "Running tests..."
xcodebuild test \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,name=$SIMULATOR,OS=latest" \
  2>&1 | $FORMATTER

echo ""
echo "Build and tests complete!"
