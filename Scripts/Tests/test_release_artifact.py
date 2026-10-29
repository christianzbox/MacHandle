"""Synthetic packaging fixtures only; no executable is launched or signed."""
import importlib.util
import json
from pathlib import Path
import plistlib
import stat
import struct
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
from types import SimpleNamespace
import zipfile

spec = importlib.util.spec_from_file_location(
    "release_artifact", Path(__file__).resolve().parents[1] / "release_artifact.py")
artifact = importlib.util.module_from_spec(spec)
spec.loader.exec_module(artifact)
REVISION = "a" * 40


class ReleaseArtifactTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="synthetic-release-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.app = self.root / "MacHandle.app"
        (self.app / "Contents/MacOS").mkdir(parents=True)
        info = {key: "synthetic" for key in artifact.PLIST_KEYS}
        info.update({
            "CFBundleIdentifier": "org.machandle.development", "CFBundleExecutable": "MacHandle",
            "CFBundleName": "MacHandle", "CFBundleDisplayName": "MacHandle",
            "CFBundlePackageType": "APPL", "CFBundleSupportedPlatforms": ["MacOSX"],
            "LSMinimumSystemVersion": "14.0", "CFBundleShortVersionString": "0.1.0",
            "CFBundleVersion": "1",
        })
        (self.app / "Contents/Info.plist").write_bytes(plistlib.dumps(info))
        (self.app / "Contents/PkgInfo").write_bytes(b"APPL????")
        executable = self.app / "Contents/MacOS/MacHandle"
        executable.write_bytes(struct.pack("<8I", 0xFEEDFACF, 0x0100000C, 0, 2, 0, 0, 0, 0))
        executable.chmod(0o755)
        self.output = self.root / "new rehearsal output"

    def create(self):
        artifact.create(self.app, self.output, REVISION)

    def reseal(self):
        data = (self.output / artifact.ARCHIVE).read_bytes()
        metadata = (self.output / artifact.MANIFEST).read_bytes()
        (self.output / artifact.CHECKSUMS).write_bytes(artifact.checksums(data, metadata))

    def cli(self, *args):
        return subprocess.run([sys.executable, artifact.__file__, *map(str, args)],
                              capture_output=True, text=True)

    def test_round_trip_records_exact_payload_and_preserves_execute_mode(self):
        self.create()
        info = artifact.verify(self.output)
        self.assertEqual(info["source_revision"], REVISION)
        self.assertEqual(info["architecture"], "arm64")
        self.assertFalse(info["release_ready"])
        with zipfile.ZipFile(self.output / artifact.ARCHIVE) as archive:
            self.assertEqual(set(archive.namelist()), {"MacHandle.app/" + p for p in artifact.FILES})
            binary = archive.getinfo("MacHandle.app/Contents/MacOS/MacHandle")
            self.assertEqual(binary.external_attr >> 16, stat.S_IFREG | 0o755)
            for name in artifact.FILES:
                self.assertEqual(archive.read("MacHandle.app/" + name), (self.app / name).read_bytes())
        second = self.root / "second"
        artifact.create(self.app, second, REVISION)
        for name in [artifact.ARCHIVE, artifact.MANIFEST, artifact.CHECKSUMS]:
            self.assertEqual((self.output / name).read_bytes(), (second / name).read_bytes())

    def test_distribution_gate_cannot_be_satisfied_by_rehearsal_or_forged_claims(self):
        self.create()
        result = self.cli("verify", self.output, "--require-distributable")
        self.assertEqual(result.returncode, 2)
        self.assertIn("Distribution blocked", result.stderr)
        info = json.loads((self.output / artifact.MANIFEST).read_bytes())
        info["release_ready"] = True
        info["signing"] = "developer-id-verified"
        (self.output / artifact.MANIFEST).write_bytes(artifact.encode(info))
        self.reseal()
        self.assertEqual(self.cli("verify", self.output).returncode, 1)

    def test_extra_private_file_and_symlink_fail_without_disclosure_or_output(self):
        private = self.app / "Contents/SYNTHETIC_PRIVATE_NAME.txt"
        private.write_text("SYNTHETIC_PRIVATE_CONTENT")
        result = self.cli("create", "--app", self.app, "--output", self.output, "--revision", REVISION)
        self.assertEqual(result.returncode, 1)
        self.assertNotIn("SYNTHETIC_PRIVATE", result.stdout + result.stderr)
        self.assertFalse(self.output.exists())
        private.unlink()
        target = self.app / "Contents/PkgInfo"
        target.unlink()
        target.symlink_to(self.root / "missing")
        with self.assertRaises(artifact.ArtifactError):
            self.create()
        self.assertFalse(self.output.exists())

    def test_extra_directory_hardlink_and_oversized_file_rejected(self):
        extra = self.app / "Contents/Private"
        extra.mkdir()
        with self.assertRaises(artifact.ArtifactError):
            self.create()
        extra.rmdir()
        source = self.app / "Contents/PkgInfo"
        # macOS may prohibit creating hardlinks inside app bundles. Simulate the metadata,
        # without weakening the production rejection or requiring filesystem privileges.
        linked = SimpleNamespace(st_mode=stat.S_IFREG | 0o644, st_nlink=2, st_size=8)
        with mock.patch.object(Path, "lstat", return_value=linked):
            with self.assertRaises(artifact.ArtifactError):
                artifact.read_regular(source, 8)
        source.write_bytes(b"APPL????extra")
        with self.assertRaises(artifact.ArtifactError):
            self.create()

    def test_existing_output_is_never_overwritten(self):
        self.output.mkdir()
        sentinel = self.output / "keep"
        sentinel.write_text("synthetic existing data")
        with self.assertRaises(FileExistsError):
            self.create()
        self.assertEqual(sentinel.read_text(), "synthetic existing data")

    def test_corruption_and_resealed_hash_mismatch_rejected(self):
        self.create()
        metadata = self.output / artifact.MANIFEST
        metadata.write_bytes(metadata.read_bytes() + b" ")
        with self.assertRaises(artifact.ArtifactError):
            artifact.verify(self.output)
        self.reseal()
        with self.assertRaises(artifact.ArtifactError):
            artifact.verify(self.output)

    def test_traversal_duplicate_and_link_archive_entries_are_not_extracted(self):
        self.create()
        archive_path = self.output / artifact.ARCHIVE
        original = archive_path.read_bytes()
        for name in ["../SYNTHETIC_PRIVATE_NAME", "MacHandle.app/Contents/PkgInfo"]:
            with self.subTest(name=name):
                archive_path.write_bytes(original)
                import warnings
                with warnings.catch_warnings():
                    warnings.simplefilter("ignore", UserWarning)
                    with zipfile.ZipFile(archive_path, "a") as archive:
                        archive.writestr(name, b"synthetic")
                self.reseal()
                with self.assertRaises(artifact.ArtifactError):
                    artifact.verify(self.output)
        archive_path.write_bytes(original)
        with zipfile.ZipFile(archive_path) as archive:
            contents = [(entry, archive.read(entry)) for entry in archive.infolist()]
        with zipfile.ZipFile(archive_path, "w") as archive:
            for entry, data in contents:
                if entry.filename.endswith("PkgInfo"):
                    entry.external_attr = (stat.S_IFLNK | 0o777) << 16
                archive.writestr(entry, data)
        self.reseal()
        with self.assertRaises(artifact.ArtifactError):
            artifact.verify(self.output)
        self.assertFalse((self.root / "SYNTHETIC_PRIVATE_NAME").exists())

    def test_wrong_identity_metadata_revision_and_architecture_rejected(self):
        plist = self.app / "Contents/Info.plist"
        original = plist.read_bytes()
        for key, value in [("CFBundleIdentifier", "synthetic.production"),
                           ("LSMinimumSystemVersion", "13.0"), ("ExtraPrivateField", "synthetic")]:
            info = plistlib.loads(original)
            info[key] = value
            plist.write_bytes(plistlib.dumps(info))
            with self.assertRaises(artifact.ArtifactError):
                self.create()
        plist.write_bytes(original)
        with self.assertRaises(artifact.ArtifactError):
            artifact.create(self.app, self.output, "not-a-commit")
        binary = self.app / "Contents/MacOS/MacHandle"
        binary.write_bytes(b"synthetic malformed executable")
        with self.assertRaises(artifact.ArtifactError):
            self.create()

    def test_artifact_folder_rejects_unlisted_files_and_manifest_links(self):
        self.create()
        extra = self.output / "extra"
        extra.write_text("synthetic")
        with self.assertRaises(artifact.ArtifactError):
            artifact.verify(self.output)
        extra.unlink()
        manifest = self.output / artifact.MANIFEST
        saved = self.root / "metadata"
        manifest.rename(saved)
        manifest.symlink_to(saved)
        with self.assertRaises(artifact.ArtifactError):
            artifact.verify(self.output)


if __name__ == "__main__":
    unittest.main()
