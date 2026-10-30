import json
from pathlib import Path
import plistlib
import shutil
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import private_test_install as install
import package_private_sample as packaging


class PrivateInstallationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve() / "sample space 🙂"

        def fake_prepare(bins, output, certificate_days):
            self.assertEqual(certificate_days, 365)
            output.mkdir()
            for name in install.FILES:
                if name.startswith("Runtime/") or name in ("Run Sample.command", "README.txt"):
                    continue
                path = output / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("synthetic placeholder")
            helper = str(output / (install.APP + "MacOS/machandle-local-mcp"))
            (output / "desktop.json").write_text(json.dumps({"server": "machandle_sample_0123456789ab", "command": helper, "args": ["--sample-writes"]}))
            (output / "package/session.json").write_text(json.dumps({"profile": "sample-writes", "helper": helper, "service": "dev.machandle.fixture.synthetic"}))
            (output / (install.APP + "Resources/PrivateBridge.json")).write_text(json.dumps({"mode": "synthetic-reminder-writes", "service": "dev.machandle.fixture.synthetic", "installation": "12345678-1234-4234-8234-123456789abc"}))
            (output / (install.APP + "Info.plist")).write_bytes(plistlib.dumps({"CFBundleIdentifier": "org.machandle.private-sample." + "a" * 32 + ".app", "CFBundleExecutable": "MacHandlePrivateWrites"}))

        self.signing = patch.object(install.subprocess, "run", return_value=SimpleNamespace(returncode=0, stdout=plistlib.dumps({"com.apple.security.app-sandbox": True})))
        self.signing.start()
        self.addCleanup(self.signing.stop)
        with patch.object(install.desktop_sample, "prepare", side_effect=fake_prepare):
            install.create(self.root / "unused", self.root, "a" * 40, "arm64")

    def reseal(self):
        path = self.root / install.MANIFEST
        metadata = json.loads(path.read_text())
        metadata["files"] = install.inventory(self.root)
        path.write_text(json.dumps(metadata))

    def test_repeated_verification_preserves_identity_and_all_bytes(self):
        before = {p.relative_to(self.root): p.read_bytes() for p in self.root.rglob("*") if p.is_file()}
        first = install.verify(self.root)
        self.assertEqual(first, install.verify(self.root))
        self.assertEqual(before, {p.relative_to(self.root): p.read_bytes() for p in self.root.rglob("*") if p.is_file()})
        self.assertEqual(first["distribution"], "local-sample-only")

    def test_changed_runtime_or_permissions_rejected(self):
        runtime = self.root / "Runtime/desktop_sample.py"
        original = runtime.read_bytes()
        runtime.write_bytes(original + b"\n# synthetic modification\n")
        with self.assertRaisesRegex(RuntimeError, "content or provenance"):
            install.verify(self.root)
        runtime.write_bytes(original)
        launcher = self.root / "Run Sample.command"
        launcher.chmod(0o600)
        with self.assertRaisesRegex(RuntimeError, "content or provenance"):
            install.verify(self.root)

    def test_unexpected_files_symlinks_and_hardlinks_refused(self):
        unexpected = self.root / "extra.txt"
        unexpected.write_text("synthetic unexpected")
        with self.assertRaises(RuntimeError):
            install.verify(self.root)
        unexpected.unlink()
        unexpected.symlink_to(self.root / "README.txt")
        with self.assertRaisesRegex(RuntimeError, "link"):
            install.verify(self.root)
        unexpected.unlink()
        unexpected.hardlink_to(self.root / "README.txt")
        with self.assertRaises(RuntimeError):
            install.verify(self.root)

    def test_relocated_installation_refused_without_changing_old_copy(self):
        other = self.root.parent / "moved"
        shutil.copytree(self.root, other)
        with self.assertRaisesRegex(RuntimeError, "desktop sample configuration"):
            install.verify(other)
        install.verify(self.root)

    def test_resealed_provider_permission_or_entitlements_refused(self):
        path = self.root / (install.APP + "Info.plist")
        original = path.read_bytes()
        info = plistlib.loads(original)
        info["NSRemindersFullAccessUsageDescription"] = "Synthetic forbidden declaration"
        path.write_bytes(plistlib.dumps(info))
        self.reseal()
        with self.assertRaisesRegex(RuntimeError, "permission declaration"):
            install.verify(self.root)
        path.write_bytes(original)
        self.reseal()
        with patch.object(install.subprocess, "run", return_value=SimpleNamespace(returncode=0, stdout=plistlib.dumps({"com.apple.security.app-sandbox": True, "com.apple.security.personal-information.calendars": True}))):
            with self.assertRaisesRegex(RuntimeError, "entitlements"):
                install.verify(self.root)

    def test_manifest_cannot_claim_release_or_change_installation_identity(self):
        path = self.root / install.MANIFEST
        original = path.read_text()
        for key, value in [("distribution", "public"), ("installation", "87654321-1234-4234-8234-123456789abc")]:
            metadata = json.loads(original)
            metadata[key] = value
            path.write_text(json.dumps(metadata))
            with self.assertRaises(RuntimeError):
                install.verify(self.root)

    def test_packaging_rejects_extended_lifetime_for_live_profile(self):
        with self.assertRaisesRegex(RuntimeError, "certificate lifetime"):
            packaging.package(self.root, self.root / "not-created", profile="isolated-reminders", certificate_days=365)
        self.assertFalse((self.root / "not-created").exists())
