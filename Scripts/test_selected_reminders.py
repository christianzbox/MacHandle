#!/usr/bin/env python3
"""Opt-in native selected-list/field acceptance, exclusively injected samples. No EventKit use."""
import argparse
import json
import os
from pathlib import Path
import tempfile

from package_private_sample import package
from run_private_sample import session
from test_private_bridge import Client, native_step


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bin-dir", type=Path, required=True)
    parser.add_argument("--interactive-native-approval", action="store_true", required=True)
    args = parser.parse_args()
    os.umask(0o077)
    with tempfile.TemporaryDirectory(prefix="selected-reminders-", dir=Path(".build").resolve()) as temporary:
        root = Path(temporary)
        canary = root / "synthetic-outside-container.txt"
        canary.write_text("synthetic sandbox denial canary")
        package(args.bin_dir.resolve(), root / "package", canary, profile="selected-sample")
        with session(root / "package") as config:
            print("APP " + config["app"], flush=True)
            native_step("Load Sample Lists; select only Synthetic selected list, Title and Completion; Start Selected Connection, then Return here.")
            client = Client(config["helper"], selected=True)
            try:
                client.initialize()
                assert client.call("list_reminder_lists")["result"]["isError"] is True
                native_step("Click Allow Selected Reads, then Return here.")
                lists = client.call("list_reminder_lists")["result"]["structuredContent"]["lists"]
                assert len(lists) == 1 and lists[0]["name"] == "Synthetic selected list"
                found = client.call("search_reminders", listIds=[lists[0]["listId"]], fields=["title", "completion"], query="", limit=5)["result"]["structuredContent"]
                assert len(found["reminders"]) == 1
                reminder = found["reminders"][0]
                assert reminder["fields"]["title"]["value"] == "Synthetic grocery reminder"
                detail = client.call("get_reminder", reminderId=reminder["reminderId"], fields=["title", "completion"])["result"]["structuredContent"]
                assert "Synthetic grocery reminder" in json.dumps(detail)
                assert "notes" not in reminder["fields"]
                assert "synthetic-hidden-reminder-canary" not in json.dumps(detail)
                assert client.call("get_reminder", reminderId=reminder["reminderId"], fields=["notes"])["result"]["isError"] is True
                assert client.call("search_reminders", listIds=["foreign-list"], fields=["title"], query="", limit=5)["result"]["isError"] is True
                assert "error" in client.call("approve")
                assert "error" in client.call("delete_reminder")
                print("PASS native selected list/fields, preapproval denial, search/detail, hidden list/notes and write/approval denial", flush=True)
                native_step("Click Stop and Clear Selection, then Return here.")
                assert client.call("list_reminder_lists")["result"]["isError"] is True
                print("PASS same-client revocation", flush=True)
            finally:
                client.close()
    print("PASS task-owned sample package, canary, signing keychains and launchd cleanup", flush=True)


if __name__ == "__main__":
    main()
