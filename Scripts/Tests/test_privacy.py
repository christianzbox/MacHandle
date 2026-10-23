import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

spec = importlib.util.spec_from_file_location(
    "check_privacy", Path(__file__).resolve().parents[1] / "check_privacy.py"
)
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)


class PrivacyChecks(unittest.TestCase):
    def test_rejects_sensitive_paths(self):
        for path in [".env", ".env.local", "Data/calendar.ICS", "x.db-wal",
                     "x.sqlite3", "x.p12", "x.keychain-db", "Private/config.json",
                     "Exports/items.json", "x.log", "x.png", "x.pem"]:
            with self.subTest(path=path):
                self.assertTrue(checker.violations(path, b"synthetic"))

    def test_rejects_binary_content_and_symlinks(self):
        self.assertTrue(checker.violations("innocent.txt", b"\xff"))
        self.assertTrue(checker.violations("innocent.txt", b"\x00"))
        self.assertTrue(checker.violations("innocent.txt", b"target", "120000"))

    def test_requires_explicit_synthetic_fixture(self):
        for content in [b"{}", b'{}[]', b'[]', b'{"_synthetic": "true"}']:
            self.assertTrue(checker.violations("Tests/Fixtures/sample.json", content))

    def test_accepts_source_docs_and_declared_synthetic_fixture(self):
        self.assertFalse(checker.violations("App/App.swift", b"import SwiftUI\n"))
        self.assertFalse(checker.violations("Docs/SECURITY_MODEL.md", b"Policy\n"))
        self.assertFalse(checker.violations(
            "Tests/Fixtures/sample.json", b'{"_synthetic": true}'
        ))

    def test_force_added_ignored_export_fails_without_disclosing_name_or_content(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(["git", "init", "--quiet", directory], check=True)
            (root / ".gitignore").write_text("*.ics\n")
            (root / "synthetic-person.ics").write_text("synthetic private event body")
            subprocess.run(["git", "-C", directory, "add", "-f", "."], check=True)
            result = subprocess.run(
                [sys.executable, checker.__file__], cwd=directory,
                capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 1)
            self.assertNotIn("synthetic-person", result.stdout + result.stderr)
            self.assertNotIn("synthetic private event body", result.stdout + result.stderr)

    def test_reads_staged_fixture_even_if_worktree_was_cleaned(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(["git", "init", "--quiet", directory], check=True)
            (root / "Fixtures").mkdir()
            fixture = root / "Fixtures" / "sample.json"
            fixture.write_text("{}")
            subprocess.run(["git", "-C", directory, "add", "."], check=True)
            fixture.write_text('{"_synthetic": true}')
            result = subprocess.run(
                [sys.executable, checker.__file__], cwd=directory,
                capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 1)
            self.assertIn("JSON fixture must declare", result.stderr)


if __name__ == "__main__":
    unittest.main()
