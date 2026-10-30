#!/usr/bin/env python3
"""Signed native approval/commit acceptance using only in-memory reminders and a sample journal.
No EventKit store, TCC request or personal iCloud access. Requires real native clicks.
"""
import argparse
import os
from pathlib import Path
import tempfile

from package_private_sample import package
from run_private_sample import session
from test_private_bridge import Client, native_step


def data(reply):
    assert not reply["result"].get("isError", False), "Sample tool unexpectedly denied"
    return reply["result"]["structuredContent"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bin-dir", type=Path, required=True)
    parser.add_argument("--interactive-native-approval", action="store_true", required=True)
    args = parser.parse_args()
    os.umask(0o077)
    with tempfile.TemporaryDirectory(prefix="sample-write-acceptance-", dir=Path(".build").resolve()) as temporary:
        root = Path(temporary)
        canary = root / "synthetic-outside-container.txt"
        canary.write_text("synthetic sandbox denial canary")
        package(args.bin_dir.resolve(), root / "package", canary, profile="sample-writes")
        with session(root / "package") as config:
            print("APP " + config["app"], flush=True)
            native_step("Select Sample list and Enable Sample Changes in the native app, then Return.")
            client = Client(config["helper"], writes=True)
            try:
                client.initialize()
                names = {v["name"] for v in client.request("tools/list", {})["result"]["tools"]}
                assert names == {"list_reminder_lists", "search_reminders", "get_reminder", "propose_reminder_change", "commit_reminder_change"}
                assert client.call("list_reminder_lists")["result"]["isError"] is True
                assert client.call("propose_reminder_change", operation="create", targetId="sample-list", title="Unpaired")["result"]["isError"] is True
                native_step("Click Allow Sample Connection, then Return.")
                lists = data(client.call("list_reminder_lists"))["lists"]
                assert len(lists) == 1 and lists[0]["name"] == "Sample list"
                list_id = lists[0]["listId"]
                rejected = data(client.call("propose_reminder_change", operation="create", targetId=list_id, title="Synthetic rejected"))["actionId"]
                native_step("Review Synthetic rejected and click Reject Proposal, then Return.")
                assert data(client.call("commit_reminder_change", actionId=rejected))["status"] == "notApproved"
                item_id = None
                for operation in ["create", "update", "setDue", "complete", "uncomplete", "delete"]:
                    extra = {"title": "Synthetic native new"} if operation == "create" else {"title": "Synthetic native revised"} if operation == "update" else {"dueDate": "2027-02-03"} if operation == "setDue" else {}
                    token = data(client.call("propose_reminder_change", operation=operation, targetId=list_id if operation == "create" else item_id, **extra))["actionId"]
                    assert data(client.call("commit_reminder_change", actionId=token))["status"] == "notApproved"
                    assert "error" in client.call("approve", actionId=token)
                    assert "error" in client.call("commit_reminder_change", actionId=token, approved=True)
                    assert client.call("propose_reminder_change", operation="create", targetId=list_id, title="Overlapping")["result"]["isError"] is True
                    native_step("Review exact " + operation + "; " + ("acknowledge deletion, then " if operation == "delete" else "") + "click Approve Exact Sample Change, then Return.")
                    assert data(client.call("commit_reminder_change", actionId=token))["status"] == "applied"
                    assert data(client.call("commit_reminder_change", actionId=token))["status"] == "notApproved"
                    found = data(client.call("search_reminders", listIds=[list_id], fields=["title", "completion", "due"], query="Synthetic native", limit=10))["reminders"]
                    if operation == "delete":
                        assert not found
                    else:
                        assert len(found) == 1
                        item_id = found[0]["reminderId"]
                        assert found[0]["fields"]["title"]["value"] == ("Synthetic native new" if operation == "create" else "Synthetic native revised")
                        if operation in ["complete", "uncomplete"]:
                            assert found[0]["fields"]["completion"]["value"]["completed"] == (operation == "complete")
                    print("PASS exact native " + operation + ", applied effect and replay denial", flush=True)
                native_step("Confirm Journal shows 6 applied / 0 unresolved. Click Stop Sample Connection, then Return.")
                assert client.call("list_reminder_lists")["result"]["isError"] is True
                print("PASS signed sample writes, rejection, no wire approval, preapproval/replay denial and revocation", flush=True)
            finally:
                client.close()
    print("PASS temporary package, signing keychain and launchd cleanup; sample UUID/state journal remains in its own sandbox container", flush=True)


if __name__ == "__main__":
    main()
