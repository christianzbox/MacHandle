#!/usr/bin/env python3
"""Temporarily register a previously built private sample package in the current GUI session.
No install at login, accounts or client configuration changes. EventKit launch is a separate opt-in;
its native UI still requires isolation acknowledgement and an explicit permission action.
"""
import argparse
import contextlib
import json
import os
from pathlib import Path
import plistlib
import subprocess
import time

from package_private_sample import PROFILES


def launchctl(*arguments, check=True):
    result = subprocess.run(["/bin/launchctl", *arguments], capture_output=True, timeout=15)
    if check and result.returncode:
        raise RuntimeError("Private sample launchd operation failed")
    return result


@contextlib.contextmanager
def session(package, allow_isolated=False):
    config = json.loads((package / "session.json").read_text())
    profile = config.get("profile", "sample")
    if profile not in PROFILES or (profile == "isolated-reminders" and not allow_isolated):
        raise RuntimeError("Isolated EventKit launch requires separate explicit authorization")
    executable, argument, _ = PROFILES[profile]
    service = config["service"]
    if not service.startswith("dev.machandle.fixture.") or len(service) > 100 or any(c not in "abcdefghijklmnopqrstuvwxyz0123456789.-" for c in service):
        raise RuntimeError("Invalid private sample service")
    plist = package / "session.plist"
    contents = plistlib.loads(plist.read_bytes())
    broker = package / "MacHandle Private.app/Contents/MacOS" / executable
    if contents != {"Label": service, "ProgramArguments": [str(broker), argument], "MachServices": {service: True}, "ProcessType": "Interactive", "LimitLoadToSessionType": "Aqua", "ExitTimeOut": 2}:
        raise RuntimeError("Unexpected private sample registration")
    target = f"gui/{os.getuid()}/{service}"
    if launchctl("print", target, check=False).returncode == 0:
        raise RuntimeError("Private sample session already running; refusing to replace it")
    try:
        launchctl("bootstrap", f"gui/{os.getuid()}", str(plist))
        if profile != "sample":
            launchctl("kickstart", target)
        yield config
    finally:
        if launchctl("print", target, check=False).returncode == 0:
            launchctl("bootout", target)
        for _ in range(50):
            if launchctl("print", target, check=False).returncode != 0:
                break
            time.sleep(0.1)
        else:
            raise RuntimeError("Private sample session cleanup failed for " + target)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, required=True)
    parser.add_argument("--allow-temporary-launch-agent", action="store_true", required=True)
    parser.add_argument("--allow-isolated-eventkit", action="store_true", help="Only in a separately authorized isolated macOS test account")
    args = parser.parse_args()
    with session(args.package.resolve(), allow_isolated=args.allow_isolated_eventkit) as config:
        print("Sample session ready. Local MCP command:" if config.get("profile", "sample") == "sample" else "Choose native lists/fields and start the selected connection before launching this helper:")
        print(json.dumps({"command": config["helper"], "args": ["--private-sample" if config.get("profile", "sample") == "sample" else "--private-reminders"]}, indent=2))
        input("Press Return here to stop and unregister the sample session.\n")
    print("Private sample session unregistered.")


if __name__ == "__main__":
    main()
