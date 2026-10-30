import json
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import desktop_sample as desktop


class DesktopSampleTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.config = self.root / "config.toml"
        self.config.write_text('model = "synthetic-model"\n[mcp_servers.existing]\ncommand = "synthetic-existing"\n')
        self.metadata = {"server": "machandle_sample_0123456789ab", "command": "/synthetic path/helper", "args": ["--sample-writes"]}
        self.calls = []

    def command(self, cli, operation, name, *arguments):
        self.calls.append(operation)
        text = self.config.read_text()
        if operation == "add":
            self.assertEqual(arguments, ("--", self.metadata["command"], "--sample-writes"))
            text += f'\n[mcp_servers.{name}]\ncommand = {json.dumps(self.metadata["command"])}\nargs = ["--sample-writes"]\n'
        else:
            start = text.index(f"[mcp_servers.{name}]")
            end = text.find("\n[", start + 1)
            text = text[:start] + (text[end:] if end != -1 else "")
        self.config.write_text(text)

    def test_cleanup_after_failure_preserves_unrelated_concurrent_settings(self):
        with patch.object(desktop, "client_command", side_effect=self.command):
            with self.assertRaisesRegex(ValueError, "fixture interruption"):
                with desktop.registration(self.metadata, "synthetic-cli", self.config):
                    with self.config.open("a") as stream:
                        stream.write('\n[mcp_servers.added_later]\ncommand = "another-synthetic-helper"\n')
                    raise ValueError("fixture interruption")
        result = desktop.read_config(self.config)
        self.assertEqual(set(result["mcp_servers"]), {"existing", "added_later"})
        self.assertEqual(result["model"], "synthetic-model")
        self.assertEqual(self.calls, ["add", "remove"])

    def test_collision_never_overwrites_or_removes_entry(self):
        self.command("synthetic-cli", "add", self.metadata["server"], "--", self.metadata["command"], "--sample-writes")
        before = self.config.read_bytes()
        with patch.object(desktop, "client_command") as command:
            with self.assertRaisesRegex(RuntimeError, "already exists"):
                with desktop.registration(self.metadata, "synthetic-cli", self.config):
                    self.fail("collision accepted")
            command.assert_not_called()
        self.assertEqual(self.config.read_bytes(), before)

    def test_changed_owned_entry_is_preserved_for_manual_review(self):
        with patch.object(desktop, "client_command", side_effect=self.command):
            with self.assertRaisesRegex(RuntimeError, "entry changed"):
                with desktop.registration(self.metadata, "synthetic-cli", self.config):
                    self.config.write_text(self.config.read_text().replace("--sample-writes", "changed-by-user"))
        self.assertIn("changed-by-user", self.config.read_text())
        self.assertEqual(self.calls, ["add"])

    def test_failed_add_that_wrote_its_entry_is_cleaned_up(self):
        def failing_add(cli, operation, name, *arguments):
            self.command(cli, operation, name, *arguments)
            if operation == "add":
                raise RuntimeError("synthetic add failure")

        before = desktop.read_config(self.config)
        with patch.object(desktop, "client_command", side_effect=failing_add):
            with self.assertRaisesRegex(RuntimeError, "add failure"):
                with desktop.registration(self.metadata, "synthetic-cli", self.config):
                    self.fail("failed add accepted")
        self.assertEqual(desktop.read_config(self.config), before)

    def test_change_during_registration_stops_and_preserves_current_settings(self):
        def changed_add(cli, operation, name, *arguments):
            self.command(cli, operation, name, *arguments)
            if operation == "add":
                self.config.write_text(self.config.read_text().replace("synthetic-model", "changed-model"))

        with patch.object(desktop, "client_command", side_effect=changed_add):
            with self.assertRaisesRegex(RuntimeError, "Other client settings changed"):
                with desktop.registration(self.metadata, "synthetic-cli", self.config):
                    self.fail("Concurrent edit accepted")
        result = desktop.read_config(self.config)
        self.assertEqual(result["model"], "changed-model")
        self.assertEqual(set(result["mcp_servers"]), {"existing"})

    def test_prepare_is_sample_only_and_does_not_launch_or_configure(self):
        output = self.root / "prepared sample 🙂"
        with patch.object(desktop, "package") as package, patch.object(desktop, "client_command") as client, patch.object(desktop, "session") as launch:
            metadata = desktop.prepare(self.root / "bin", output)
            package.assert_called_once_with(self.root / "bin", output / "package", output / "synthetic-outside-container.txt", profile="sample-writes")
            client.assert_not_called()
            launch.assert_not_called()
        self.assertEqual(metadata["args"], ["--sample-writes"])
        self.assertEqual(desktop.read_config(output / "client-preview.toml")["mcp_servers"][metadata["server"]]["command"], metadata["command"])
        with self.assertRaises(FileExistsError):
            desktop.prepare(self.root / "bin", output)

    def fixture_package(self):
        helper = self.root / "package/MacHandle Private.app/Contents/MacOS/machandle-local-mcp"
        resources = helper.parent.parent / "Resources"
        resources.mkdir(parents=True)
        self.metadata["command"] = str(helper)
        (self.root / "desktop.json").write_text(json.dumps(self.metadata))
        (self.root / "package/session.json").write_text(json.dumps({"profile": "sample-writes", "helper": str(helper), "service": "synthetic"}))
        (resources / "PrivateBridge.json").write_text(json.dumps({"mode": "synthetic-reminder-writes", "service": "synthetic"}))

    def test_modified_command_or_live_profile_refused_before_launch(self):
        self.fixture_package()
        for change in ["command", "args", "env"]:
            metadata = dict(self.metadata)
            metadata[change] = "synthetic-unexpected-value"
            (self.root / "desktop.json").write_text(json.dumps(metadata))
            with self.assertRaisesRegex(RuntimeError, "Unexpected desktop"):
                desktop.inspect_prepared(self.root)
        (self.root / "desktop.json").write_text(json.dumps(self.metadata))
        (self.root / "package/session.json").write_text(json.dumps({"profile": "isolated-reminders"}))
        with self.assertRaisesRegex(RuntimeError, "Only the prepared"):
            desktop.inspect_prepared(self.root)

    def test_invalid_signature_refused_before_launch(self):
        self.fixture_package()
        with patch.object(desktop.subprocess, "run", return_value=SimpleNamespace(returncode=1)):
            with self.assertRaisesRegex(RuntimeError, "signature"):
                desktop.inspect_prepared(self.root)

    def test_failed_client_command_never_echoes_client_output(self):
        with patch.object(desktop.subprocess, "run", return_value=SimpleNamespace(returncode=1, stdout=b"synthetic-sensitive-output")):
            with self.assertRaisesRegex(RuntimeError, "^Desktop MCP configuration command failed$"):
                desktop.client_command("synthetic-cli", "add")
