#!/usr/bin/env python3
"""Temporarily register a previously built private sample package in the current GUI session.
No install at login, accounts, provider permissions or client configuration changes.
"""
import argparse
import contextlib
import json
import os
from pathlib import Path
import plistlib
import subprocess
import time


def launchctl(*arguments, check=True):
    result = subprocess.run(["/bin/launchctl", *arguments], capture_output=True, timeout=15)
    if check and result.returncode:
        raise RuntimeError("Private sample launchd operation failed")
    return result


@contextlib.contextmanager
def session(package):
    config = json.loads((package / "session.json").read_text())
    service = config["service"]
    if not service.startswith("dev.machandle.fixture.") or len(service) > 100 or any(c not in "abcdefghijklmnopqrstuvwxyz0123456789.-" for c in service):
        raise RuntimeError("Invalid private sample service")
    plist = package / "session.plist"
    contents = plistlib.loads(plist.read_bytes())
    broker = package / "MacHandle Private.app/Contents/MacOS/MacHandlePrivateSample"
    if contents != {"Label": service, "ProgramArguments": [str(broker), "--private-sample"], "MachServices": {service: True}, "ProcessType": "Interactive", "LimitLoadToSessionType": "Aqua", "ExitTimeOut": 2}:
        raise RuntimeError("Unexpected private sample registration")
    target = f"gui/{os.getuid()}/{service}"
    if launchctl("print", target, check=False).returncode == 0:
        raise RuntimeError("Private sample session already running; refusing to replace it")
    try:
        launchctl("bootstrap", f"gui/{os.getuid()}", str(plist))
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
    args = parser.parse_args()
    with session(args.package.resolve()) as config:
        print("Sample session ready. Local MCP command:")
        print(json.dumps({"command": config["helper"], "args": ["--private-sample"]}, indent=2))
        input("Press Return here to stop and unregister the sample session.\n")
    print("Private sample session unregistered.")


if __name__ == "__main__":
    main()
