#!/usr/bin/env python3
"""Local development packaging only. No signing, notarization, launch or publication."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import plistlib
import re
import shutil
import stat
import struct
import sys
import zipfile

ARCHIVE = "MacHandle-development.zip"
MANIFEST = "manifest.json"
CHECKSUMS = "SHA256SUMS"
FILES = {
    "Contents/Info.plist": (64 * 1024, 0o644),
    "Contents/PkgInfo": (8, 0o644),
    "Contents/MacOS/MacHandle": (128 * 1024 * 1024, 0o755),
}
DIRECTORIES = {"Contents", "Contents/MacOS"}
PLIST_KEYS = {
    "BuildMachineOSBuild", "CFBundleDevelopmentRegion", "CFBundleDisplayName",
    "CFBundleExecutable", "CFBundleIdentifier", "CFBundleInfoDictionaryVersion",
    "CFBundleName", "CFBundlePackageType", "CFBundleShortVersionString",
    "CFBundleSupportedPlatforms", "CFBundleVersion", "DTCompiler", "DTPlatformBuild",
    "DTPlatformName", "DTPlatformVersion", "DTSDKBuild", "DTSDKName", "DTXcode",
    "DTXcodeBuild", "LSMinimumSystemVersion", "NSCalendarsFullAccessUsageDescription",
    "NSContactsUsageDescription", "NSRemindersFullAccessUsageDescription",
}


class ArtifactError(Exception):
    """Only fixed messages are shown; never echo untrusted names, content or tool errors."""


def require(condition, message):
    if not condition:
        raise ArtifactError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def read_regular(path, limit):
    info = path.lstat()
    require(stat.S_ISREG(info.st_mode) and info.st_nlink == 1 and info.st_size <= limit,
            "Unexpected file type or size.")
    with path.open("rb") as stream:
        value = stream.read(limit + 1)
    require(len(value) <= limit, "File exceeds the packaging limit.")
    return value


def inspect_payload(payload):
    require(set(payload) == set(FILES), "Unexpected bundle contents.")
    require(all(len(payload[name]) <= bound for name, (bound, _) in FILES.items()),
            "Bundle exceeds the packaging limit.")
    info = plistlib.loads(payload["Contents/Info.plist"])
    require(isinstance(info, dict) and set(info) == PLIST_KEYS,
            "Unexpected bundle metadata keys; review the packaging policy.")
    expected = {
        "CFBundleIdentifier": "org.machandle.development", "CFBundleExecutable": "MacHandle",
        "CFBundleName": "MacHandle", "CFBundleDisplayName": "MacHandle",
        "CFBundlePackageType": "APPL", "CFBundleSupportedPlatforms": ["MacOSX"],
        "LSMinimumSystemVersion": "14.0",
    }
    require(all(info.get(key) == value for key, value in expected.items()),
            "Bundle identity or minimum OS does not match the development profile.")
    require(all(isinstance(value, str) and len(value) <= 2048 for key, value in info.items()
                if key != "CFBundleSupportedPlatforms"), "Invalid bundle metadata values.")
    require(re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", info["CFBundleShortVersionString"])
            and re.fullmatch(r"[0-9]+", info["CFBundleVersion"]), "Invalid development version.")
    require(all(info[key].strip() for key in PLIST_KEYS if key.endswith("UsageDescription")),
            "Missing privacy usage description.")
    require(payload["Contents/PkgInfo"] == b"APPL????", "Invalid bundle package marker.")
    binary = payload["Contents/MacOS/MacHandle"]
    require(len(binary) >= 32, "Missing executable header.")
    magic, cpu, _, kind = struct.unpack_from("<IIII", binary)
    require(magic == 0xFEEDFACF and kind == 2 and cpu in (0x0100000C, 0x01000007),
            "Expected one native arm64 or x86_64 executable; universal packaging is not verified.")
    return {
        "bundle_id": info["CFBundleIdentifier"],
        "version": info["CFBundleShortVersionString"], "build": info["CFBundleVersion"],
        "minimum_macos": info["LSMinimumSystemVersion"],
        "architecture": "arm64" if cpu == 0x0100000C else "x86_64",
    }


def read_bundle(app):
    require(not app.is_symlink() and app.is_dir(), "Expected a regular app directory.")
    files, directories = {}, set()
    for path in app.rglob("*"):
        name = path.relative_to(app).as_posix()
        mode = path.lstat().st_mode
        require(not path.is_symlink(), "Bundle links are not allowed.")
        if stat.S_ISDIR(mode):
            directories.add(name)
        else:
            require(name in FILES, "Unexpected bundle file; nothing was packaged.")
            files[name] = read_regular(path, FILES[name][0])
            if name == "Contents/MacOS/MacHandle":
                require(mode & stat.S_IXUSR, "Bundle executable is not executable.")
    require(directories == DIRECTORIES, "Unexpected bundle directories.")
    inspect_payload(files)
    return files


def manifest(revision, payload, archive_bytes):
    require(isinstance(revision, str) and re.fullmatch(r"[0-9a-f]{40}", revision),
            "Expected a full source commit SHA.")
    return {
        "schema": 1, "kind": "development-rehearsal", "source_revision": revision,
        "release_ready": False, "signing": "developer-id-not-verified",
        "notarization": "not-performed", **inspect_payload(payload),
        "archive": {"name": ARCHIVE, "sha256": digest(archive_bytes)},
        "files": {name: digest(data) for name, data in sorted(payload.items())},
    }


def encode(value):
    return (json.dumps(value, sort_keys=True, indent=2) + "\n").encode()


def checksums(archive, metadata):
    return f"{digest(archive)}  {ARCHIVE}\n{digest(metadata)}  {MANIFEST}\n".encode()


def create(app, output, revision):
    payload = read_bundle(app)
    # Validate revision before creating any output; never overwrite an existing destination.
    manifest(revision, payload, b"")
    require(not output.resolve().is_relative_to(app.resolve()), "Output must be outside the app.")
    output.mkdir(mode=0o700)
    try:
        with zipfile.ZipFile(output / ARCHIVE, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            for name, data in sorted(payload.items()):
                entry = zipfile.ZipInfo("MacHandle.app/" + name, (1980, 1, 1, 0, 0, 0))
                entry.create_system = 3
                entry.external_attr = (stat.S_IFREG | FILES[name][1]) << 16
                entry.compress_type = zipfile.ZIP_DEFLATED
                archive.writestr(entry, data)
        archive_bytes = read_regular(output / ARCHIVE, 129 * 1024 * 1024)
        metadata = encode(manifest(revision, payload, archive_bytes))
        (output / MANIFEST).write_bytes(metadata)
        (output / CHECKSUMS).write_bytes(checksums(archive_bytes, metadata))
        verify(output)
    except BaseException:
        shutil.rmtree(output)  # Only the new directory successfully created above.
        raise


def verify(directory):
    require(not directory.is_symlink() and directory.is_dir(), "Expected an artifact directory.")
    require({p.name for p in directory.iterdir()} == {ARCHIVE, MANIFEST, CHECKSUMS},
            "Unexpected artifact files.")
    archive_bytes = read_regular(directory / ARCHIVE, 129 * 1024 * 1024)
    metadata = read_regular(directory / MANIFEST, 16384)
    sums = read_regular(directory / CHECKSUMS, 1024)
    require(sums == checksums(archive_bytes, metadata), "Artifact checksum mismatch.")
    info = json.loads(metadata)
    require(isinstance(info, dict), "Invalid artifact manifest.")
    payload = {}
    # Read bytes only; never extract, launch, sign or trust a supplied archive path.
    with zipfile.ZipFile(io.BytesIO(archive_bytes)) as archive:
        expected = {"MacHandle.app/" + name for name in FILES}
        entries = archive.infolist()
        require(len(entries) == len(expected) and {e.filename for e in entries} == expected,
                "Unexpected archive entries.")
        require(not archive.comment, "Unexpected archive metadata.")
        for entry in entries:
            name = entry.filename[len("MacHandle.app/"):]
            limit, mode = FILES[name]
            require(entry.file_size <= limit and not entry.extra and not entry.comment
                    and entry.create_system == 3
                    and entry.external_attr >> 16 == stat.S_IFREG | mode,
                    "Unexpected archive metadata or file size.")
            payload[name] = archive.read(entry)
    require(metadata == encode(manifest(info.get("source_revision"), payload, archive_bytes)),
            "Manifest does not match the development artifact.")
    return info


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    build = commands.add_parser("create", help="Internal packaging helper; prefer package_development.sh")
    build.add_argument("--app", type=Path, required=True)
    build.add_argument("--output", type=Path, required=True)
    build.add_argument("--revision", required=True)
    check = commands.add_parser("verify")
    check.add_argument("directory", type=Path)
    check.add_argument("--require-distributable", action="store_true")
    args = parser.parse_args()
    try:
        if args.command == "create":
            create(args.app, args.output, args.revision)
        else:
            verify(args.directory)
            if args.require_distributable:
                print("Distribution blocked: development artifact; signing, notarization and release acceptance remain open.", file=sys.stderr)
                return 2
        print("Development artifact integrity verified. NOT RELEASE READY; no signature or live behavior verified.")
        return 0
    except Exception:  # Untrusted corrupt archives must never cause a raw traceback/content leak.
        print("Artifact validation failed; no untrusted paths or content are printed. Review the packaging policy.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
