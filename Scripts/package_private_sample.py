#!/usr/bin/env python3
"""Build an account-free private read app and MCP relay. Defaults to samples; never launches.

A disposable local certificate signs both peers; its private key/keychain are removed. No Apple
account, employer identity, system trust setting or existing keychain identity is used.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import secrets
import shutil
import subprocess
import tempfile
import uuid

APP_ID = "org.machandle.private-sample"


def run(args, env=None):
    result = subprocess.run(args, capture_output=True, env=env, timeout=60)
    if result.returncode:
        # Commands can contain disposable passwords. Never print arguments, output or exception text.
        raise RuntimeError("Private sample packaging step failed: " + Path(args[0]).name)
    return result


PROFILES = {
    "sample-writes": ("MacHandlePrivateWrites", "--sample-writes", "synthetic-reminder-writes"),
    "sample": ("MacHandlePrivateSample", "--private-sample", "synthetic-reminders-only"),
    "selected-sample": ("MacHandlePrivateReminders", "--selected-sample", "selected-synthetic-reminders"),
    "isolated-reminders": ("MacHandlePrivateReminders", "--isolated-reminders", "isolated-eventkit-reminders"),
}


def package(bin_dir, output, canary=None, service=None, profile="sample"):
    executable, argument, mode = PROFILES[profile]
    output.mkdir(mode=0o700, parents=False, exist_ok=False)
    app = output / "MacHandle Private.app"
    contents = app / "Contents"
    (contents / "MacOS").mkdir(parents=True)
    (contents / "Resources").mkdir()
    broker = contents / "MacOS" / executable
    helper = contents / "MacOS" / "machandle-local-mcp"
    shutil.copy2(bin_dir / broker.name, broker)
    shutil.copy2(bin_dir / helper.name, helper)
    service = service or "dev.machandle.fixture." + uuid.uuid4().hex
    identity_root = APP_ID + "." + uuid.uuid4().hex
    app_id = identity_root + ".app"
    helper_id = identity_root + ".helper"
    info = {
        "CFBundleIdentifier": app_id, "CFBundleExecutable": broker.name, "CFBundlePackageType": "APPL",
        "CFBundleName": "MacHandle Private", "CFBundleDisplayName": "MacHandle Private — Sample Reminders" if profile == "sample" else "MacHandle Private — Sample Changes" if profile == "sample-writes" else "MacHandle Private — Selected Reminders",
        "CFBundleVersion": "1", "CFBundleShortVersionString": "0.0.1", "LSMinimumSystemVersion": "14.0",
        "NSPrincipalClass": "NSApplication",
    }
    if profile == "isolated-reminders":
        info["NSRemindersFullAccessUsageDescription"] = "Read selected sample reminder lists in an isolated macOS test account. Apple grants read and write access; this app exposes reads only."
    (contents / "Info.plist").write_bytes(plistlib.dumps(info))
    config = {"mode": mode, "service": service}
    if profile == "sample-writes":
        config["installation"] = str(uuid.uuid4())
    if canary is not None:
        if not canary.is_file():
            raise RuntimeError("Acceptance canary must already exist")
        config["sandboxCanary"] = str(canary.resolve())
    (contents / "Resources" / "PrivateBridge.json").write_text(json.dumps(config))
    with tempfile.TemporaryDirectory(prefix="machandle-private-signing-") as temporary:
        work = Path(temporary)
        password = secrets.token_hex(32)
        env = os.environ.copy()
        env["MACHANDLE_FIXTURE_PASSWORD"] = password
        config_path = work / "certificate.cnf"
        config_path.write_text("[req]\ndistinguished_name=dn\nx509_extensions=ext\nprompt=no\n[dn]\nCN=MacHandle private sample\n[ext]\nbasicConstraints=critical,CA:TRUE\nkeyUsage=critical,digitalSignature,keyCertSign\nextendedKeyUsage=critical,codeSigning\n")
        run(["/usr/bin/openssl", "req", "-new", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "7",
             "-config", str(config_path), "-keyout", str(work / "key.pem"), "-out", str(work / "certificate.pem")])
        run(["/usr/bin/openssl", "pkcs12", "-export", "-inkey", str(work / "key.pem"), "-in", str(work / "certificate.pem"),
             "-out", str(work / "identity.p12"), "-passout", "env:MACHANDLE_FIXTURE_PASSWORD"], env=env)
        fingerprint = run(["/usr/bin/openssl", "x509", "-in", str(work / "certificate.pem"), "-noout", "-fingerprint", "-sha1"]).stdout.decode().strip().split("=")[1].replace(":", "")
        keychain = work / "identity.keychain-db"
        try:
            run(["/usr/bin/security", "create-keychain", "-p", password, str(keychain)])
            run(["/usr/bin/security", "unlock-keychain", "-p", password, str(keychain)])
            run(["/usr/bin/security", "import", str(work / "identity.p12"), "-k", str(keychain), "-P", password, "-T", "/usr/bin/codesign"])
            run(["/usr/bin/security", "set-key-partition-list", "-S", "apple-tool:,apple:", "-s", "-k", password, str(keychain)])
            base = ["/usr/bin/codesign", "--force", "--sign", fingerprint, "--keychain", str(keychain), "--timestamp=none", "--options", "runtime"]
            run(base + ["--identifier", helper_id, str(helper)])
            entitlements = work / "entitlements.plist"
            rights = {"com.apple.security.app-sandbox": True}
            if profile == "isolated-reminders":
                rights["com.apple.security.personal-information.calendars"] = True
            entitlements.write_bytes(plistlib.dumps(rights))
            run(base + ["--entitlements", str(entitlements), str(app)])
            run(["/usr/bin/codesign", "--verify", "--strict", "--deep", str(app)])
        finally:
            if keychain.exists():
                run(["/usr/bin/security", "delete-keychain", str(keychain)])
    plist = output / "session.plist"
    plist.write_bytes(plistlib.dumps({
        "Label": service, "ProgramArguments": [str(broker), argument], "MachServices": {service: True},
        "ProcessType": "Interactive", "LimitLoadToSessionType": "Aqua", "ExitTimeOut": 2,
    }))
    (output / "session.json").write_text(json.dumps({"service": service, "app": str(app), "helper": str(helper), "plist": str(plist), "profile": profile}, indent=2))
    (output / "SHA256SUMS").write_text("\n".join(hashlib.sha256(p.read_bytes()).hexdigest() + "  " + str(p.relative_to(output)) for p in [broker, helper, plist]) + "\n")
    return app


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bin-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--sandbox-canary", type=Path)
    parser.add_argument("--profile", choices=PROFILES, default="sample")
    args = parser.parse_args()
    os.umask(0o077)
    app = package(args.bin_dir.resolve(), args.output.resolve(), args.sandbox_canary, profile=args.profile)
    print("Packaged private native app (not launched); disposable signing keychain removed: " + str(app))


if __name__ == "__main__":
    main()
