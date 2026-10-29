#!/bin/bash
# Build committed source only, without accounts, signing, launch, uploads or release credentials.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ "$#" -ne 1 ]; then
  echo "Usage: bash Scripts/package_development.sh NEW_OUTPUT_DIRECTORY" >&2
  exit 1
fi
source Scripts/check_environment.sh
machandle_check_environment
if [ -n "$(git status --porcelain --untracked-files=normal)" ]; then
  echo "Commit or preserve local changes before packaging; a clean checkout is required." >&2
  exit 1
fi
machandle_revision=$(git rev-parse --verify HEAD)
machandle_output=$(python3 -c 'import pathlib,sys; print(pathlib.Path(sys.argv[1]).absolute())' "$1")
if [ -e "$machandle_output" ] || [ -L "$machandle_output" ]; then
  echo "Output must be a new directory; existing files are never replaced." >&2
  exit 1
fi
python3 - "$machandle_output" <<'PYTHON'
from pathlib import Path
import sys
if Path(sys.argv[1]).resolve().is_relative_to(Path.cwd().resolve()):
    print("Output must be outside the source checkout.", file=sys.stderr)
    sys.exit(1)
PYTHON
machandle_arch=$(uname -m)
case "$machandle_arch" in arm64|x86_64) ;; *) echo "Unsupported rehearsal architecture." >&2; exit 1 ;; esac
machandle_temp=$(mktemp -d "${TMPDIR:-/tmp}/machandle-package.XXXXXX")
trap 'rm -rf "$machandle_temp"' EXIT
mkdir "$machandle_temp/source"
# The repository privacy gate rejects tracked links/submodules; archive excludes ignored local state.
python3 Scripts/check_privacy.py
git archive --format=tar "$machandle_revision" > "$machandle_temp/source.tar"
tar -xf "$machandle_temp/source.tar" -C "$machandle_temp/source"
(
  cd "$machandle_temp/source"
  # Verify the archived toolchain too. No mismatch override or provisioning updates.
  bash Scripts/check_environment.sh
  xcodebuild -project MacHandle.xcodeproj -scheme MacHandle -configuration Release \
    -destination 'generic/platform=macOS' -derivedDataPath "$machandle_temp/build" \
    ARCHS="$machandle_arch" ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= DEVELOPMENT_TEAM= build
) > "$machandle_temp/build.log" 2>&1 || {
  echo "Clean-source build failed. Reproduce locally using the pinned toolchain; build paths/logs are not exported." >&2
  exit 1
}
python3 "$machandle_temp/source/Scripts/release_artifact.py" create \
  --app "$machandle_temp/build/Build/Products/Release/MacHandle.app" \
  --output "$machandle_output" --revision "$machandle_revision"
echo "Packaged one host architecture from the recorded commit. No app was launched or published."
