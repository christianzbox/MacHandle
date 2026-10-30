#!/usr/bin/env python3
"""Prepare/run a temporary ChatGPT desktop STDIO connection to synthetic reminders only.

Preparation signs a new sample package without launching or changing client configuration.
Run requires explicit flags, preserves unrelated client entries and removes only its own unchanged
entry. No model/API calls, credentials, provider permissions or public distribution are involved.
"""
import argparse
import contextlib
import copy
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import tomllib
import uuid

from package_private_sample import package
from run_private_sample import session


def prepare(bin_dir, output, certificate_days=7):
    output.mkdir(mode=0o700, parents=False, exist_ok=False)
    canary = output / "synthetic-outside-container.txt"
    canary.write_text("synthetic sandbox denial canary")
    package(bin_dir, output / "package", canary, profile="sample-writes", certificate_days=certificate_days)
    name = "machandle_sample_" + uuid.uuid4().hex[:12]
    helper = output / "package/MacHandle Private.app/Contents/MacOS/machandle-local-mcp"
    metadata = {"server": name, "command": str(helper), "args": ["--sample-writes"]}
    (output / "desktop.json").write_text(json.dumps(metadata, indent=2) + "\n")
    # Preview only. The run command uses the supported CLI instead of replacing config.toml.
    (output / "client-preview.toml").write_text(
        f"[mcp_servers.{name}]\ncommand = {json.dumps(str(helper), ensure_ascii=False)}\nargs = [\"--sample-writes\"]\n"
    )
    return metadata


def inspect_prepared(root):
    metadata = json.loads((root / "desktop.json").read_text())
    name = metadata.get("server", "")
    helper = root / "package/MacHandle Private.app/Contents/MacOS/machandle-local-mcp"
    expected = {"server": name, "command": str(helper), "args": ["--sample-writes"]}
    if not re.fullmatch(r"machandle_sample_[0-9a-f]{12}", name) or metadata != expected:
        raise RuntimeError("Unexpected desktop sample configuration")
    config = json.loads((root / "package/session.json").read_text())
    bridge = json.loads((helper.parent.parent / "Resources/PrivateBridge.json").read_text())
    if config.get("profile") != "sample-writes" or config.get("helper") != str(helper):
        raise RuntimeError("Only the prepared sample-write helper is allowed")
    if bridge.get("mode") != "synthetic-reminder-writes" or bridge.get("service") != config.get("service"):
        raise RuntimeError("Unexpected signed sample mode or service")
    result = subprocess.run(["/usr/bin/codesign", "--verify", "--strict", "--deep", str(helper.parent.parent.parent)],
                            capture_output=True, timeout=30)
    if result.returncode:
        raise RuntimeError("Sample package signature verification failed")
    return metadata


def read_config(path):
    return tomllib.loads(path.read_text()) if path.exists() else {}


def without_entry(config, name):
    result = copy.deepcopy(config)
    servers = result.get("mcp_servers", {})
    servers.pop(name, None)
    if not servers:
        result.pop("mcp_servers", None)
    return result


def client_command(cli, *arguments):
    result = subprocess.run([cli, "mcp", *arguments], capture_output=True, timeout=30)
    if result.returncode:
        # Client output/configuration can contain credentials. Never echo it or command arguments.
        raise RuntimeError("Desktop MCP configuration command failed")


def terminate(*_):
    raise SystemExit(143)


@contextlib.contextmanager
def registration(metadata, cli, config_path):
    name = metadata["server"]
    before = read_config(config_path)
    if name in before.get("mcp_servers", {}):
        raise RuntimeError("Sample server already exists; refusing to replace it")
    expected = {"command": metadata["command"], "args": metadata["args"]}
    attempted = False
    try:
        attempted = True
        client_command(cli, "add", name, "--", metadata["command"], *metadata["args"])
        added = read_config(config_path)
        if added.get("mcp_servers", {}).get(name) != expected:
            raise RuntimeError("Desktop sample registration did not match the prepared command")
        if without_entry(added, name) != without_entry(before, name):
            raise RuntimeError("Other client settings changed during registration; inspect locally")
        yield
    finally:
        if attempted:
            current = read_config(config_path)
            entry = current.get("mcp_servers", {}).get(name)
            if entry is not None:
                if entry != expected:
                    raise RuntimeError("Sample entry changed; preserved for manual inspection instead of removal")
                client_command(cli, "remove", name)
                after = read_config(config_path)
                if name in after.get("mcp_servers", {}) or without_entry(after, name) != without_entry(current, name):
                    raise RuntimeError("Desktop configuration cleanup needs local inspection")


def run_prepared(root):
    metadata = inspect_prepared(root)
    cli = shutil.which("codex")
    if cli is None:
        raise RuntimeError("Supported desktop CLI not found; no automatic client fallback")
    config_path = Path(os.environ.get("CODEX_HOME", str(Path.home() / ".codex"))) / "config.toml"
    signal.signal(signal.SIGTERM, terminate)
    with session(root / "package"):
        print("APP " + str(root / "package/MacHandle Private.app"), flush=True)
        input("Select Sample list, then Enable Sample Changes in the native window; Return here.\n")
        with registration(metadata, cli, config_path):
            print("Registered " + metadata["server"] + "; connect in a new desktop session and approve native pairing.", flush=True)
            input("Finish the desktop acceptance checklist and Stop Sample Connection, then Return to remove this entry.\n")
    print("Removed temporary client entry and launchd job. Sample journal/container preserved.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="action", required=True)
    create = commands.add_parser("prepare")
    create.add_argument("--bin-dir", type=Path, required=True)
    create.add_argument("--output", type=Path, required=True)
    launch = commands.add_parser("run")
    launch.add_argument("--prepared", type=Path, required=True)
    launch.add_argument("--allow-temporary-client-config", action="store_true", required=True)
    launch.add_argument("--allow-temporary-launch-agent", action="store_true", required=True)
    args = parser.parse_args()
    os.umask(0o077)
    if args.action == "prepare":
        metadata = prepare(args.bin_dir.resolve(), args.output.resolve())
        print("Prepared sample-only desktop server: " + metadata["server"])
        print("Nothing launched or registered. Review client-preview.toml before run.")
        return
    run_prepared(args.prepared.resolve())


if __name__ == "__main__":
    main()
