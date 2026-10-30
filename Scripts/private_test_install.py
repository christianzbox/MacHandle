#!/usr/bin/env python3
"""Create/verify/run a local, reusable sample installation. Never upgrades or resets a journal."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import stat
import subprocess
import sys
import uuid

sys.dont_write_bytecode = True
import desktop_sample

MANIFEST = "installation.json"
RUNTIME = ("private_test_install.py", "desktop_sample.py", "run_private_sample.py", "package_private_sample.py")
APP = "package/MacHandle Private.app/Contents/"
FILES = {
    "desktop.json", "client-preview.toml", "synthetic-outside-container.txt",
    "package/session.json", "package/session.plist", "package/SHA256SUMS",
    APP + "Info.plist", APP + "Resources/PrivateBridge.json", APP + "_CodeSignature/CodeResources",
    APP + "MacOS/MacHandlePrivateWrites", APP + "MacOS/machandle-local-mcp",
    "Run Sample.command", "README.txt", *("Runtime/" + name for name in RUNTIME),
}


def inventory(root):
    found = {}
    for path in root.rglob("*"):
        info = path.lstat()
        if stat.S_ISLNK(info.st_mode) or not (stat.S_ISDIR(info.st_mode) or stat.S_ISREG(info.st_mode)):
            raise RuntimeError("Installation contains a link or special file")
        if path.is_dir():
            if not any(name.startswith(path.relative_to(root).as_posix() + "/") for name in FILES):
                raise RuntimeError("Unexpected installation directory")
            continue
        name = path.relative_to(root).as_posix()
        if info.st_nlink != 1 or info.st_size > 64 * 1024 * 1024:
            raise RuntimeError("Unexpected installation file")
        if name == MANIFEST:
            continue
        if name not in FILES:
            raise RuntimeError("Unexpected installation member")
        found[name] = {"sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "mode": stat.S_IMODE(info.st_mode)}
    if set(found) != FILES:
        raise RuntimeError("Installation members missing")
    return found


def create(bin_dir, output, revision, architecture):
    if not re.fullmatch(r"[0-9a-f]{40}", revision) or architecture not in ("arm64", "x86_64"):
        raise RuntimeError("Invalid build provenance")
    desktop_sample.prepare(bin_dir, output, certificate_days=365)
    runtime = output / "Runtime"
    runtime.mkdir()
    for name in RUNTIME:
        shutil.copy2(Path(__file__).parent / name, runtime / name)
    launcher = output / "Run Sample.command"
    launcher.write_text('''#!/bin/bash
set -euo pipefail
machandle_install=$(cd "$(dirname "$0")" && pwd -P)
cd "$machandle_install"
python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)' || {
  echo "Python 3.11 or newer is required; see README.txt." >&2
  exit 1
}
exec python3 -B "$machandle_install/Runtime/private_test_install.py" run \\
  --installation "$machandle_install" --allow-temporary-client-config --allow-temporary-launch-agent
''')
    launcher.chmod(0o700)
    (output / "README.txt").write_text(
        "MacHandle PRIVATE SAMPLE TEST — not the full live application\n\n"
        "No Apple/Google developer account, API key or personal iCloud access is needed.\n"
        "Requires macOS GUI session, Python 3.11+ and the verified desktop CLI on PATH.\n"
        "Run from Terminal: bash 'Run Sample.command'\n"
        "This explicitly starts a temporary native job and adds one temporary desktop MCP entry.\n"
        "Select Sample list and Enable in the native window, then Return in Terminal.\n"
        "Use a fresh desktop session; allow native pairing and approve each exact sample write.\n"
        "Stop the native connection, disconnect the client and Return in Terminal to clean up.\n"
        "Keep this directory at its original path. Reuse it; do not rebuild between sessions.\n"
        "Reminder contents reset on restart; the operation journal does not. Unknowns block work.\n"
        "Never rebuild/delete as recovery. No in-place upgrade, journal migration or auto-update.\n"
        "Local certificate has a 365-day validity period; no private signing key is retained.\n"
        "No Gatekeeper bypass, public distribution or another-Mac compatibility is claimed.\n\n"
        f"Source: {revision}\n"
        f"Checklist: https://github.com/christianzbox/MacHandle/blob/{revision}/docs/development/private-testing-handoff.md\n"
    )
    bridge = json.loads((output / (APP + "Resources/PrivateBridge.json")).read_text())
    info = plistlib.loads((output / (APP + "Info.plist")).read_bytes())
    metadata = {
        "schema": 1, "sourceRevision": revision, "configuration": "Release", "architecture": architecture,
        "profile": "synthetic-reminder-writes", "installation": bridge["installation"],
        "bundleIdentifier": info["CFBundleIdentifier"], "certificateValidityDays": 365,
        "distribution": "local-sample-only", "files": inventory(output),
    }
    (output / MANIFEST).write_text(json.dumps(metadata, indent=2, sort_keys=True) + "\n")
    verify(output)


def verify(root):
    if root.is_symlink() or not root.is_dir():
        raise RuntimeError("Installation must be its original directory")
    files = inventory(root)
    metadata = json.loads((root / MANIFEST).read_text())
    if set(metadata) != {"schema", "sourceRevision", "configuration", "architecture", "profile", "installation",
                         "bundleIdentifier", "certificateValidityDays", "distribution", "files"}:
        raise RuntimeError("Unexpected installation manifest")
    if (metadata["schema"] != 1 or metadata["configuration"] != "Release"
            or metadata["profile"] != "synthetic-reminder-writes" or metadata["distribution"] != "local-sample-only"
            or metadata["certificateValidityDays"] != 365 or metadata["architecture"] not in ("arm64", "x86_64")
            or not re.fullmatch(r"[0-9a-f]{40}", metadata["sourceRevision"]) or metadata["files"] != files):
        raise RuntimeError("Installation content or provenance changed")
    info = plistlib.loads((root / (APP + "Info.plist")).read_bytes())
    bridge = json.loads((root / (APP + "Resources/PrivateBridge.json")).read_text())
    if (info.get("CFBundleIdentifier") != metadata["bundleIdentifier"]
            or not re.fullmatch(r"org\.machandle\.private-sample\.[0-9a-f]{32}\.app", metadata["bundleIdentifier"])
            or info.get("CFBundleExecutable") != "MacHandlePrivateWrites"
            or any(key.endswith("UsageDescription") for key in info)
            or bridge.get("installation") != metadata["installation"]
            or str(uuid.UUID(metadata["installation"])) != metadata["installation"]):
        raise RuntimeError("Unexpected sample identity or permission declaration")
    desktop_sample.inspect_prepared(root)
    result = subprocess.run(["/usr/bin/codesign", "--display", "--entitlements", ":-", str(root / "package/MacHandle Private.app")],
                            capture_output=True, timeout=30)
    if result.returncode or plistlib.loads(result.stdout) != {"com.apple.security.app-sandbox": True}:
        raise RuntimeError("Unexpected sample entitlements")
    return metadata


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="action", required=True)
    build = commands.add_parser("create", help="Internal helper; use build_private_test.sh for clean-source provenance")
    build.add_argument("--bin-dir", type=Path, required=True)
    build.add_argument("--output", type=Path, required=True)
    build.add_argument("--revision", required=True)
    build.add_argument("--architecture", required=True)
    for action in ("verify", "run"):
        command = commands.add_parser(action)
        command.add_argument("--installation", type=Path, required=True)
        if action == "run":
            command.add_argument("--allow-temporary-client-config", action="store_true", required=True)
            command.add_argument("--allow-temporary-launch-agent", action="store_true", required=True)
    args = parser.parse_args()
    os.umask(0o077)
    if args.action == "create":
        create(args.bin_dir.resolve(), args.output.absolute(), args.revision, args.architecture)
        print("Created reusable local sample installation; nothing launched or registered.")
    else:
        root = args.installation.absolute()
        metadata = verify(root)
        print("Verified local sample installation from " + metadata["sourceRevision"])
        if args.action == "run":
            desktop_sample.run_prepared(root)


if __name__ == "__main__":
    main()
