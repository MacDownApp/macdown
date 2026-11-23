#!/bin/sh
# Builds MacDown (Debug) into ./build and opens it, optionally with a file.
#   Tools/run.sh [file.md]
# First time on a new clone:  git submodule update --init && pod install
#                              make -C Dependency/peg-markdown-highlight
set -e
cd "$(dirname "$0")/.."
xcodebuild -workspace MacDown.xcworkspace -scheme MacDown -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath build build CODE_SIGNING_ALLOWED=NO -quiet
APP="$PWD/build/Build/Products/Debug/MacDown.app"
if [ -n "$1" ]; then open -a "$APP" "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"; else open -a "$APP"; fi
