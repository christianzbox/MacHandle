#!/usr/bin/env python3
"""Check indexed files without logging their contents. Heuristic, not a DLP guarantee."""

import json
from pathlib import PurePosixPath
import subprocess
import sys

BLOCKED_SUFFIXES = {
    ".ics", ".vcf", ".db", ".sqlite", ".sqlite3", ".log", ".pem", ".key",
    ".p12", ".pfx", ".cer", ".mobileprovision", ".keychain", ".keychain-db",
    ".png", ".jpg", ".jpeg", ".heic", ".pdf", ".zip", ".dmg",
}
BLOCKED_DIRECTORIES = {
    "local", "private", "secrets", "diagnostics", "exports", "deriveddata",
    "xcuserdata", ".build", "__pycache__",
}


def violations(path: str, content: bytes, mode: str = "100644") -> list[str]:
    """Return reasons only; never include potentially sensitive payloads."""
    name = PurePosixPath(path.lower())
    reasons = []
    if mode not in {"100644", "100755"}:
        reasons.append("symlinks and submodules require explicit review")
    if (name.suffix in BLOCKED_SUFFIXES
            or name.name.startswith(".env")
            or name.name.endswith(("-wal", "-shm", "-journal"))
            or any(part in BLOCKED_DIRECTORIES for part in name.parts[:-1])):
        reasons.append("sensitive or generated file type/location")
    try:
        content.decode("utf-8")
        if b"\x00" in content:
            reasons.append("binary content requires explicit review")
    except UnicodeDecodeError:
        reasons.append("non-text content requires explicit review")
    if "fixtures" in name.parts and name.suffix == ".json":
        try:
            fixture = json.loads(content)
            if not isinstance(fixture, dict) or fixture.get("_synthetic") is not True:
                reasons.append("JSON fixture must declare _synthetic: true")
        except (ValueError, UnicodeDecodeError):
            reasons.append("invalid JSON fixture")
    return reasons


def main() -> int:
    entries = subprocess.check_output(["git", "ls-files", "--stage", "-z"]).split(b"\0")
    failures = 0
    for entry in filter(None, entries):
        metadata, raw_path = entry.split(b"\t", 1)
        mode, oid, stage = metadata.decode().split()
        if stage != "0":
            print("Privacy check: unresolved index conflict", file=sys.stderr)
            return 1
        content = subprocess.check_output(["git", "cat-file", "blob", oid])
        reasons = violations(raw_path.decode("utf-8"), content, mode)
        if reasons:
            failures += 1
            # Do not print filenames: user exports can contain personal names.
            print("Privacy check: " + "; ".join(reasons), file=sys.stderr)
    if failures:
        print(f"Privacy check failed for {failures} indexed files.", file=sys.stderr)
        return 1
    print("Privacy check passed for indexed files; manual content review is still required.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
