#!/bin/bash
# Source this file to select Xcode for subsequent commands in the same process.
machandle_check_environment() {
  local script_dir allow_mismatch=0 candidate selected="" fallback=""
  local xcode_info swift_info sdk_info tool
  script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd) || return 1
  source "$script_dir/../Config/Toolchain.env"
  if [ "${1:-}" = "--allow-toolchain-mismatch" ] && [ "$#" -eq 1 ]; then
    if [ "${CI:-}" = true ]; then
      echo "Toolchain mismatch overrides are not allowed in CI." >&2
      return 1
    fi
    allow_mismatch=1
  elif [ "$#" -ne 0 ]; then
    echo "Usage: check_environment.sh [--allow-toolchain-mismatch]" >&2
    return 1
  fi
  if [ "$(uname -s)" != Darwin ]; then
    echo "App validation requires macOS and full Xcode." >&2
    return 1
  fi
  for tool in git python3 xcrun xcodebuild curl shasum tar; do
    command -v "$tool" >/dev/null || { echo "Missing required tool: $tool" >&2; return 1; }
  done
  python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)' || {
    echo "Python 3.9 or newer is required for repository checks." >&2
    return 1
  }
  # Honor an explicit location, including a renamed Xcode outside /Applications.
  # Otherwise try the selected developer directory and standard installation locations.
  local candidates=()
  if [ -n "${DEVELOPER_DIR:-}" ]; then
    candidates=("$DEVELOPER_DIR")
  else
    candidates=("$(xcode-select -p 2>/dev/null || true)" /Applications/Xcode*.app/Contents/Developer)
  fi
  for candidate in "${candidates[@]}"; do
    if [ -d "$candidate/Contents/Developer" ]; then
      candidate="$candidate/Contents/Developer"
    fi
    [ -x "$candidate/usr/bin/xcodebuild" ] || continue
    [ -n "$fallback" ] || fallback="$candidate"
    xcode_info=$(DEVELOPER_DIR="$candidate" xcodebuild -version 2>/dev/null) || continue
    if [ "$xcode_info" = "$(printf 'Xcode %s\nBuild version %s' "$MACHANDLE_XCODE_VERSION" "$MACHANDLE_XCODE_BUILD")" ]; then
      selected="$candidate"
      break
    fi
  done
  selected=${selected:-$fallback}
  if [ -z "$selected" ]; then
    echo "Full Xcode is missing. Install the baseline from Config/Toolchain.env; see docs/development/setup.md." >&2
    echo "Set DEVELOPER_DIR to its app or Contents/Developer directory if installed elsewhere." >&2
    return 1
  fi
  export DEVELOPER_DIR="$selected"
  xcode_info=$(xcodebuild -version) || return 1
  swift_info=$(xcrun swift --version) || return 1
  sdk_info=$(xcrun --sdk macosx --show-sdk-version) || return 1
  printf '%s\n%s\nmacOS SDK %s\n' "$xcode_info" "$swift_info" "$sdk_info"
  if [ "$xcode_info" != "$(printf 'Xcode %s\nBuild version %s' "$MACHANDLE_XCODE_VERSION" "$MACHANDLE_XCODE_BUILD")" ] \
    || ! printf '%s\n' "$swift_info" | grep -Fq "Apple Swift version $MACHANDLE_SWIFT_VERSION (" \
    || [ "$sdk_info" != "$MACHANDLE_MACOS_SDK" ]; then
    echo "Expected Xcode $MACHANDLE_XCODE_VERSION ($MACHANDLE_XCODE_BUILD), Swift $MACHANDLE_SWIFT_VERSION, SDK $MACHANDLE_MACOS_SDK." >&2
    if [ "$allow_mismatch" -ne 1 ]; then
      echo "Toolchain mismatch. See docs/development/setup.md; select the baseline with DEVELOPER_DIR." >&2
      return 1
    fi
    echo "SUPPLEMENTAL COMPATIBILITY CHECK ONLY: this is not baseline validation." >&2
  else
    echo "Shared toolchain baseline verified."
  fi
  xcrun --find swift-format >/dev/null || return 1
  git --version
  python3 --version
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  set -euo pipefail
  machandle_check_environment "$@"
fi
