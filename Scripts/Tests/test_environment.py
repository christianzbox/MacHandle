"""Exercise preflight failure modes using synthetic tool executables, not fake CI results."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class EnvironmentChecks(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory(prefix="machandle setup ")
        self.addCleanup(self.scratch.cleanup)
        self.root = Path(self.scratch.name)
        self.developer = self.root / "Renamed Xcode.app" / "Contents" / "Developer"
        self.bin = self.developer / "usr" / "bin"
        self.bin.mkdir(parents=True)
        self.baseline = dict(
            line.split("=", 1) for line in
            (ROOT / "Config/Toolchain.env").read_text().splitlines()
            if line and not line.startswith("#")
        )
        self.executable("uname", "printf 'Darwin\\n'")
        # Apple's /usr/bin/git dispatches through the selected developer directory.
        self.executable("git", "printf 'git version 2.54.0 (synthetic)\\n'")
        self.executable("xcodebuild", '''printf 'Xcode %s\\nBuild version %s\\n' "$FAKE_XCODE" "$FAKE_BUILD"''')
        self.executable("xcrun", '''
case "$*" in
  'swift --version') printf 'Apple Swift version %s (synthetic-toolchain)\\n' "$FAKE_SWIFT" ;;
  '--sdk macosx --show-sdk-version') printf '%s\\n' "$FAKE_SDK" ;;
  '--find swift-format') printf '/synthetic/swift-format\\n' ;;
  *) exit 1 ;;
esac
''')

    def executable(self, name, body):
        target = self.bin / name
        target.write_text("#!/bin/bash\n" + body + "\n")
        target.chmod(0o755)

    def run_check(self, *args, **overrides):
        env = {
            **os.environ,
            "PATH": str(self.bin) + os.pathsep + os.environ["PATH"],
            "DEVELOPER_DIR": str(self.developer),
            "CI": "false",
            "FAKE_XCODE": self.baseline["MACHANDLE_XCODE_VERSION"],
            "FAKE_BUILD": self.baseline["MACHANDLE_XCODE_BUILD"],
            "FAKE_SWIFT": self.baseline["MACHANDLE_SWIFT_VERSION"],
            "FAKE_SDK": self.baseline["MACHANDLE_MACOS_SDK"],
            **overrides,
        }
        return subprocess.run(
            ["/bin/bash", str(ROOT / "Scripts/check_environment.sh"), *args],
            cwd=self.root, env=env, capture_output=True, text=True,
        )

    def test_custom_location_spaces_and_unrelated_working_directory(self):
        result = self.run_check(DEVELOPER_DIR=str(self.developer.parents[1]))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Shared toolchain baseline verified", result.stdout)

    def test_rejects_each_drift_dimension(self):
        for key in ("FAKE_XCODE", "FAKE_BUILD", "FAKE_SWIFT", "FAKE_SDK"):
            with self.subTest(key=key):
                result = self.run_check(**{key: "unexpected"})
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Toolchain mismatch", result.stderr)

    def test_missing_full_xcode_has_actionable_error(self):
        result = self.run_check(DEVELOPER_DIR=str(self.root / "CommandLineTools"))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Full Xcode is missing", result.stderr)
        self.assertIn("docs/development/setup.md", result.stderr)

    def test_discovers_selected_xcode_without_changing_global_selection(self):
        self.executable("xcode-select", '''
if [ "$*" = '-p' ]; then printf '%s\\n' "$FAKE_SELECTED"; else exit 1; fi
''')
        result = self.run_check(DEVELOPER_DIR="", FAKE_SELECTED=str(self.developer))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Shared toolchain baseline verified", result.stdout)

    def test_selects_xcode_before_invoking_developer_tool_python(self):
        # Model Apple's launcher needing a usable per-process developer selection.
        # A standalone Python installation would hide this ordering regression.
        self.executable("xcode-select", '''
if [ "$*" = '-p' ]; then printf '%s\\n' "$FAKE_SELECTED"; else exit 1; fi
''')
        self.executable("python3", '''
if [ "${DEVELOPER_DIR:-}" != "$FAKE_SELECTED" ]; then
  echo 'synthetic Python launcher: developer directory not selected' >&2
  exit 1
fi
if [ "$1" = '--version' ]; then printf 'Python 3.11.0 (synthetic)\\n'; fi
''')
        result = self.run_check(DEVELOPER_DIR="", FAKE_SELECTED=str(self.developer))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Shared toolchain baseline verified", result.stdout)

    def test_local_override_is_labeled_supplemental(self):
        result = self.run_check("--allow-toolchain-mismatch", FAKE_XCODE="unexpected")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("SUPPLEMENTAL COMPATIBILITY CHECK ONLY", result.stderr)
        self.assertNotIn("Shared toolchain baseline verified", result.stdout)

    def test_ci_cannot_override_baseline(self):
        result = self.run_check("--allow-toolchain-mismatch", CI="true")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("not allowed in CI", result.stderr)


if __name__ == "__main__":
    unittest.main()
