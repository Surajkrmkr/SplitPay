#!/bin/sh

# Fail this script if any command fails.
set -e

# Navigate to the root of the repository
cd "$CI_PRIMARY_REPOSITORY_PATH"

# Install Flutter SDK (stable channel)
git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter
export PATH="$PATH:$HOME/flutter/bin"

# Precache iOS Flutter engine artifacts (downloads Flutter.xcframework)
flutter precache --ios

# Ensure CocoaPods is installed
brew install cocoapods || true

# Run flutter pub get to fetch packages and generate Flutter configuration
flutter pub get

# Install iOS CocoaPods dependencies
cd ios
pod install

exit 0
