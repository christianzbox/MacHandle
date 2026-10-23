#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Respect an explicit selection without changing the machine's global xcode-select.
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcodebuild -version
xcrun swift --version
xcrun --sdk macosx --show-sdk-version
xcrun swift-format lint --strict --recursive Package.swift App Sources Tests
xcrun swift build -Xswiftc -warnings-as-errors
xcrun swift test -Xswiftc -warnings-as-errors
xcodebuild -project MacHandle.xcodeproj -scheme MacHandle -configuration Debug \
  -destination 'generic/platform=macOS' -derivedDataPath .build/xcode \
  CODE_SIGNING_ALLOWED=NO build analyze
xcodebuild -project MacHandle.xcodeproj -scheme MacHandle -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath .build/xcode \
  CODE_SIGNING_ALLOWED=NO build
python3 -m unittest discover -s Scripts/Tests -v
python3 Scripts/check_privacy.py
git diff --check
git diff --cached --check
