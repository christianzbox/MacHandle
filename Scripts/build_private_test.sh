#!/bin/bash
# Clean committed source -> reusable local sample installation. Never launches or publishes.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ "$#" -ne 1 ]; then
  echo "Usage: bash Scripts/build_private_test.sh NEW_FINAL_INSTALLATION_DIRECTORY" >&2
  exit 1
fi
source Scripts/check_environment.sh
machandle_check_environment
python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)' || {
  echo "Private desktop testing requires Python 3.11 or newer." >&2
  exit 1
}
if [ -n "$(git status --porcelain --untracked-files=normal)" ]; then
  echo "Clean committed source is required. Preserve/commit changes before building." >&2
  exit 1
fi
machandle_revision=$(git rev-parse --verify HEAD)
machandle_output=$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).absolute())' "$1")
python3 - "$machandle_output" <<'PYTHON'
from pathlib import Path
import sys
p = Path(sys.argv[1])
if p.exists() or p.is_symlink() or not p.parent.is_dir() or p.resolve().is_relative_to(Path.cwd().resolve()):
    sys.exit("Choose a new final directory outside the checkout, with an existing parent.")
if p != p.resolve():
    sys.exit("Use a physical destination path without symlinks or dot components.")
PYTHON
machandle_temp=$(mktemp -d "${TMPDIR:-/tmp}/machandle-private-build.XXXXXX")
trap 'rm -rf "$machandle_temp"' EXIT
mkdir "$machandle_temp/source"
python3 Scripts/check_privacy.py
git archive --format=tar "$machandle_revision" > "$machandle_temp/source.tar"
tar -xf "$machandle_temp/source.tar" -C "$machandle_temp/source"
(
  cd "$machandle_temp/source"
  bash Scripts/check_environment.sh
  xcrun swift build -c release --product MacHandlePrivateWrites -Xswiftc -warnings-as-errors
  xcrun swift build -c release --product machandle-local-mcp -Xswiftc -warnings-as-errors
  machandle_bin=$(xcrun swift build -c release --show-bin-path)
  python3 -B Scripts/private_test_install.py create --bin-dir "$machandle_bin" \
    --output "$machandle_output" --revision "$machandle_revision" --architecture "$(uname -m)"
) > "$machandle_temp/build.log" 2>&1 || {
  echo "Private clean-source build failed. Keep any partial output separate; it is not verified. No app launched." >&2
  exit 1
}
echo "Created verified local sample installation at: $machandle_output"
echo "No client configuration, launchd registration, account or macOS permission changed."
