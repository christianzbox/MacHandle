#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Version and archive hashes verified against the upstream GitHub release assets.
version=8.30.1
case "$(uname -s)-$(uname -m)" in
  Darwin-arm64) platform=darwin_arm64; digest=b40ab0ae55c505963e365f271a8d3846efbc170aa17f2607f13df610a9aeb6a5 ;;
  Darwin-x86_64) platform=darwin_x64; digest=dfe101a4db2255fc85120ac7f3d25e4342c3c20cf749f2c20a18081af1952709 ;;
  Linux-x86_64) platform=linux_x64; digest=551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb ;;
  *) echo "Unsupported scanner host" >&2; exit 1 ;;
esac
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
archive="gitleaks_${version}_${platform}.tar.gz"
curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 \
  "https://github.com/gitleaks/gitleaks/releases/download/v${version}/${archive}" \
  --output "$scratch/$archive"
(cd "$scratch" && printf '%s  %s\n' "$digest" "$archive" | shasum -a 256 -c -)
tar -xzf "$scratch/$archive" -C "$scratch" gitleaks
"$scratch/gitleaks" git --redact=100 --no-banner --log-opts=--all .
# Scan exactly what is staged too, including newly added files before the first commit.
mkdir "$scratch/index"
git checkout-index --all --prefix="$scratch/index/"
"$scratch/gitleaks" dir --redact=100 --no-banner "$scratch/index"
