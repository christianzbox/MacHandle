#!/usr/bin/env python3
"""Opt-in, account-free cross-process proof. Only synthetic providers and task-owned files.

Temporarily bootstraps a UUID-named per-user launchd job, then removes it in finally.
Never installs in Library, changes login items, uses a signing certificate or opens Apple data.
"""
import argparse
import contextlib
import json
import os
from pathlib import Path
import plistlib
import re
import selectors
import shutil
import subprocess
import tempfile
import uuid


def run(*args, check=True):
    return subprocess.run(args, check=check, capture_output=True, timeout=15)


def sign(source, destination, identifier, different=False):
    shutil.copy2(source, destination)
    args = ["/usr/bin/codesign", "--force", "--sign", "-", "--timestamp=none", "--identifier", identifier]
    if different:
        args += ["--options", "runtime"]
    run(*args, str(destination))
    run("/usr/bin/codesign", "--verify", "--strict", str(destination))
    output = run("/usr/bin/codesign", "-d", "--verbose=4", str(destination)).stderr.decode()
    match = re.search(r"^CDHash=([a-f0-9]{40})$", output, re.MULTILINE)
    assert match, "Missing fixture code hash"
    return match[1]


@contextlib.contextmanager
def broker(root, executable, helper_hash, helper_id, approved=True):
    service = "dev.machandle.fixture." + uuid.uuid4().hex
    domain = f"gui/{os.getuid()}"
    target = domain + "/" + service
    path = root / (service + ".plist")
    path.write_bytes(plistlib.dumps({
        "Label": service,
        "ProgramArguments": [str(executable), "--fixture", service, helper_hash, helper_id,
                             "--sample-only", "approved" if approved else "denied"],
        "MachServices": {service: True},
        "ProcessType": "Background",
        "ExitTimeOut": 2,
        "StandardOutPath": str(root / (service + ".events")),
    }))
    # No KeepAlive, RunAtLoad, permanent install, content logs, environment secrets or provider access.
    try:
        run("/bin/launchctl", "bootstrap", domain, str(path))
        yield service
    finally:
        # Also recover a job installed just before a bootstrap timeout/error. The UUID label is ours.
        if run("/bin/launchctl", "print", target, check=False).returncode == 0:
            run("/bin/launchctl", "bootout", target)
            assert run("/bin/launchctl", "print", target, check=False).returncode != 0, "Fixture job survived cleanup"
        path.unlink(missing_ok=True)
        (root / (service + ".events")).unlink(missing_ok=True)


@contextlib.contextmanager
def helper(executable, service, broker_hash, broker_id):
    process = subprocess.Popen([str(executable), "--fixture", service, broker_hash, broker_id, "--sample-only"],
                               stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    try:
        yield process
    finally:
        if process.poll() is None:
            process.stdin.close()
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=3)
        # Never print process diagnostics, payloads or environment.
        process.stdout.close()
        process.stderr.close()


def request(process, payload):
    process.stdin.write(json.dumps(payload, separators=(",", ":")).encode() + b"\n")
    process.stdin.flush()
    with selectors.DefaultSelector() as selector:
        selector.register(process.stdout, selectors.EVENT_READ)
        assert selector.select(timeout=5), "Fixture reply timed out"
        line = process.stdout.readline(32770)
    assert line.endswith(b"\n") and len(line) <= 32769, "Unbounded/absent fixture reply"
    return json.loads(line)


def envelope(tool="list_reminder_lists", **arguments):
    return {"version": 1, "tool": tool, "arguments": arguments}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bin-dir", type=Path, required=True)
    parser.add_argument("--allow-temporary-launch-agent", action="store_true", required=True)
    args = parser.parse_args()
    helper_id = "dev.machandle.fixture.helper"
    broker_id = "dev.machandle.fixture.broker"
    with tempfile.TemporaryDirectory(prefix="machandle-external-fixture-") as temporary:
        root = Path(temporary)
        os.chmod(root, 0o700)
        probe = root / "helper"
        host = root / "broker"
        impostor = root / "impostor"
        helper_hash = sign(args.bin_dir / "machandle-bridge-probe", probe, helper_id)
        broker_hash = sign(args.bin_dir / "machandle-sample-broker", host, broker_id)
        impostor_hash = sign(args.bin_dir / "machandle-bridge-probe", impostor, helper_id, different=True)
        assert impostor_hash != helper_hash

        with broker(root, host, helper_hash, helper_id) as service:
            with helper(probe, service, broker_hash, broker_id) as process:
                lists = request(process, envelope())["result"]["lists"]
                assert len(lists) == 1
                data = request(process, envelope("search_reminders", listIds=[lists[0]["listId"]], query="", fields=["title", "completion"], limit=5))
                encoded = json.dumps(data)
                assert (root / (service + ".events")).read_text() == "sample-channel\n"
                assert "Synthetic grocery reminder" in encoded
                assert "synthetic-hidden-reminder-canary" not in encoded
                assert request(process, {**envelope(), "approve": True}) == {"error": "invalidRequest"}
                assert request(process, envelope("delete_reminder")) == {"error": "invalidRequest"}
            # A second launch cannot silently reuse the first launch's approval.
            with helper(probe, service, broker_hash, broker_id) as process:
                assert request(process, envelope()) == {"error": "unavailable"}
        print("PASS external process reads, projection, no wire approval/write and no launch reuse")

        with broker(root, host, helper_hash, helper_id, approved=False) as service:
            with helper(probe, service, broker_hash, broker_id) as process:
                assert request(process, envelope()) == {"error": "unavailable"}
        print("PASS authenticated but unapproved launch denied")

        for case, executable, expected_hash, expected_id in [
            ("wrong helper code hash with same identifier", impostor, helper_hash, helper_id),
            ("wrong helper identifier", probe, helper_hash, helper_id + ".wrong"),
        ]:
            with broker(root, host, expected_hash, expected_id) as service:
                with helper(executable, service, broker_hash, broker_id) as process:
                    assert request(process, envelope()) == {"error": "unavailable"}
                events = root / (service + ".events")
                assert not events.exists() or events.read_bytes() == b"", "Rejected peer reached broker factory"
            print("PASS " + case)

        for case, expected_hash, expected_id in [
            ("wrong broker code hash", "0" * 40, broker_id),
            ("wrong broker identifier", broker_hash, broker_id + ".wrong"),
        ]:
            with broker(root, host, helper_hash, helper_id) as service:
                with helper(probe, service, expected_hash, expected_id) as process:
                    assert request(process, envelope()) == {"error": "unavailable"}
                events = root / (service + ".events")
                assert not events.exists() or events.read_bytes() == b"", "Rejected peer reached broker factory"
            print("PASS " + case)

        with broker(root, host, helper_hash, helper_id) as service:
            with helper(probe, service, broker_hash, broker_id) as process:
                assert "result" in request(process, envelope())
                run("/bin/launchctl", "kill", "SIGTERM", f"gui/{os.getuid()}/{service}")
                assert request(process, envelope()) == {"error": "unavailable"}
        print("PASS broker termination closes the existing helper channel")

        absent = "dev.machandle.fixture." + uuid.uuid4().hex
        with helper(probe, absent, broker_hash, broker_id) as process:
            assert request(process, envelope()) == {"error": "unavailable"}
        print("PASS absent broker fails closed")
    print("PASS task-owned launchd jobs and fixture directory removed")


if __name__ == "__main__":
    main()
