import json
from pathlib import Path
import plistlib
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import package_private_sample as packaging
import run_private_sample as launch


class PrivateProfileTests(unittest.TestCase):
    def test_samples_have_no_provider_permission_and_isolated_profile_is_explicit(self):
        for profile in packaging.PROFILES:
            with self.subTest(profile=profile), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                bins = root / "bin"
                bins.mkdir()
                for name in ["MacHandlePrivateSample", "MacHandlePrivateReminders", "MacHandlePrivateWrites", "machandle-local-mcp"]:
                    (bins / name).write_bytes(b"synthetic executable placeholder")
                rights = []

                def fake_run(args, env=None):
                    if "--entitlements" in args:
                        rights.append(plistlib.loads(Path(args[args.index("--entitlements") + 1]).read_bytes()))
                    return SimpleNamespace(stdout=b"sha1 Fingerprint=" + b"AA:" * 19 + b"AA\n")

                with patch.object(packaging, "run", side_effect=fake_run):
                    app = packaging.package(bins, root / "package", profile=profile)
                info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
                config = json.loads((app / "Contents/Resources/PrivateBridge.json").read_text())
                isolated = profile == "isolated-reminders"
                self.assertEqual("NSRemindersFullAccessUsageDescription" in info, isolated)
                self.assertEqual(rights, [{"com.apple.security.app-sandbox": True, **({"com.apple.security.personal-information.calendars": True} if isolated else {})}])
                self.assertEqual(config["mode"], packaging.PROFILES[profile][2])
                self.assertNotIn("NSCalendarsFullAccessUsageDescription", info)

    def test_isolated_registration_requires_separate_launch_opt_in(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "session.json").write_text(json.dumps({"profile": "isolated-reminders"}))
            with patch.object(launch, "launchctl") as call:
                with self.assertRaises(RuntimeError):
                    with launch.session(root):
                        self.fail("Unexpected activation")
                call.assert_not_called()
