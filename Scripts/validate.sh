#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

source Scripts/check_environment.sh
machandle_check_environment "$@"
xcrun swift-format lint --strict --recursive Package.swift App Sources Tests
xcrun swift build -Xswiftc -warnings-as-errors
xcrun swift test -Xswiftc -warnings-as-errors
bash Scripts/check_domain_boundaries.sh
python3 Scripts/test_mcp_stdio.py --executable "$(xcrun swift build --show-bin-path)/machandle-mcp"
xcodebuild -project MacHandle.xcodeproj -scheme MacHandle -configuration Debug \
  -destination 'generic/platform=macOS' -derivedDataPath .build/xcode \
  COMPILATION_CACHE_ENABLE_CACHING=YES \
  COMPILATION_CACHE_CAS_PATH="$PWD/.build/compilation-cache" \
  COMPILATION_CACHE_ENABLE_DIAGNOSTIC_REMARKS=YES \
  CODE_SIGNING_ALLOWED=NO -showBuildTimingSummary build analyze
xcodebuild -project MacHandle.xcodeproj -scheme MacHandle -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath .build/xcode \
  COMPILATION_CACHE_ENABLE_CACHING=YES \
  COMPILATION_CACHE_CAS_PATH="$PWD/.build/compilation-cache" \
  COMPILATION_CACHE_ENABLE_DIAGNOSTIC_REMARKS=YES \
  CODE_SIGNING_ALLOWED=NO -showBuildTimingSummary build
python3 -m unittest discover -s Scripts/Tests -v
python3 Scripts/check_privacy.py
git diff --check
git diff --cached --check
