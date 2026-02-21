#!/bin/bash
set -e

PROJECT="GifKeyboard.xcodeproj"
SCHEME="GifKeyboard"
SIMULATOR="iPhone 17 Pro"

echo "Building GifKeyboard for iOS Simulator..."
xcodebuild build \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,name=$SIMULATOR,OS=latest" \
  | xcpretty || cat

echo ""
echo "Running tests..."
xcodebuild test \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,name=$SIMULATOR,OS=latest" \
  | xcpretty || cat

echo ""
echo "Build and tests complete!"
