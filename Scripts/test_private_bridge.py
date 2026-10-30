#!/usr/bin/env python3
"""Opt-in packaged native/MCP acceptance. Requires two real native UI actions, never auto-approves.

Build/signing inputs are synthetic. Uses a temporary local keychain/certificate and GUI-session job.
No Apple account, personal provider, TCC request, permanent service or client config is used.
"""
import argparse
import json
import os
from pathlib import Path
import selectors
import shutil
import subprocess
import sys
import tempfile

from package_private_sample import package
from run_private_sample import session


class Client:
    def __init__(self, helper):
        self.process = subprocess.Popen([str(helper), "--private-sample"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.identifier = 0

    def request(self, method, parameters):
        self.identifier += 1
        value = {"jsonrpc": "2.0", "id": self.identifier, "method": method, "params": parameters}
        self.process.stdin.write(json.dumps(value).encode() + b"\n")
        self.process.stdin.flush()
        with selectors.DefaultSelector() as selector:
            selector.register(self.process.stdout, selectors.EVENT_READ)
            assert selector.select(timeout=8), "MCP response deadline"
            line = self.process.stdout.readline(65537)
        assert line.endswith(b"\n") and len(line) <= 65536, "Invalid/absent MCP reply"
        return json.loads(line)

    def initialize(self):
        result = self.request("initialize", {"protocolVersion": "2025-11-25", "capabilities": {}, "clientInfo": {"name": "MacHandle sample acceptance", "version": "1"}})
        assert result["result"]["serverInfo"]["name"] == "MacHandle private sample MCP"
        self.process.stdin.write(b'{"jsonrpc":"2.0","method":"notifications/initialized"}\n')
        self.process.stdin.flush()

    def call(self, name, **arguments):
        return self.request("tools/call", {"name": name, "arguments": arguments})

    def close(self):
        if self.process.poll() is None:
            self.process.stdin.close()
            try:
                self.process.wait(timeout=4)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait(timeout=4)
        for stream in [self.process.stdout, self.process.stderr]:
            stream.close()


def rejected(helper):
    result = subprocess.run([str(helper), "--private-sample"], input=b"", capture_output=True, timeout=8)
    assert result.returncode != 0 and not result.stdout, "Unexpected helper activation"


def native_step(message):
    print(message, flush=True)
    # UI action is performed by a person or external UI automation, not a hidden approval API.
    ready, _, _ = __import__("select").select([sys.stdin], [], [], 55)
    assert ready and sys.stdin.readline() != "", "Native review action not confirmed within its deadline"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bin-dir", type=Path, required=True)
    parser.add_argument("--interactive-native-approval", action="store_true", required=True)
    args = parser.parse_args()
    os.umask(0o077)
    # Outside the app bundle/container, readable by the unsandboxed harness before the app starts.
    with tempfile.TemporaryDirectory(prefix="private-acceptance-", dir=Path(".build").resolve()) as temporary:
        root = Path(temporary)
        canary = root / "synthetic-outside-container.txt"
        canary.write_text("synthetic sandbox denial canary")
        package(args.bin_dir.resolve(), root / "primary", canary)
        config = json.loads((root / "primary/session.json").read_text())
        helper = Path(config["helper"])
        rejected(helper)  # Broker absent; no synthetic local fallback.
        tampered = root / "tampered"
        shutil.copytree(root / "primary", tampered)
        (tampered / "MacHandle Private.app/Contents/Resources/PrivateBridge.json").write_text('{}')
        rejected(tampered / "MacHandle Private.app/Contents/MacOS/machandle-local-mcp")
        package(args.bin_dir.resolve(), root / "other", service=config["service"])
        other = json.loads((root / "other/session.json").read_text())
        with session(root / "primary"):
            rejected(other["helper"])  # Wrong issuer cannot claim the listener before its legitimate peer.
            client = Client(helper)
            try:
                client.initialize()
                assert canary.read_text() == "synthetic sandbox denial canary"
                tools = client.request("tools/list", {})["result"]["tools"]
                assert {tool["name"] for tool in tools} == {"list_reminder_lists", "search_reminders", "get_reminder"}
                assert client.call("list_reminder_lists")["result"]["isError"] is True
                assert "error" in client.call("approve")
                print("PASS sealed package, absent broker, read-only catalog and unapproved denial", flush=True)
                print("APP " + config["app"], flush=True)
                native_step("Click Allow Sample Reads in the native sample app, then press Return here.")
                lists = client.call("list_reminder_lists")["result"]["structuredContent"]["lists"]
                assert len(lists) == 1 and lists[0]["name"] == "Synthetic selected list"
                found = client.call("search_reminders", listIds=[lists[0]["listId"]], query="", fields=["title", "completion"], limit=5)["result"]["structuredContent"]
                assert len(found["reminders"]) == 1
                reminder = found["reminders"][0]
                assert reminder["fields"]["title"]["value"] == "Synthetic grocery reminder"
                assert "notes" not in reminder["fields"]
                assert "synthetic-hidden-reminder-canary" not in json.dumps(found)
                assert client.call("get_reminder", reminderId=reminder["reminderId"], fields=["notes"])["result"]["isError"] is True
                assert "error" in client.call("delete_reminder")
                rejected(helper)  # A second launch cannot reuse approval.
                rejected(other["helper"])  # Different local issuer/build, same service discovery name.
                print("PASS native approval, selected title/completion reads, hidden fields, write denial, launch/issuer isolation", flush=True)
                native_step("Click Revoke Sample Access in the native sample app, then press Return here.")
                assert client.call("list_reminder_lists")["result"]["isError"] is True
                print("PASS native revocation denies the same MCP client", flush=True)
            finally:
                client.close()
        rejected(helper)
    print("PASS temporary jobs, packages, canary and signing keychains cleaned up", flush=True)


if __name__ == "__main__":
    main()
