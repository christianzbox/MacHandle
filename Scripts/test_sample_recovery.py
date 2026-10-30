#!/usr/bin/env python3
"""Sample-only signed process restart, disconnect and fresh-approval acceptance.
Kills only its UUID-named sample broker job. Never accesses EventKit, TCC or personal iCloud.
"""
import argparse
import os
from pathlib import Path
import tempfile

from package_private_sample import package
from run_private_sample import launchctl, session
from test_private_bridge import Client, native_step
from test_sample_writes import data


def paired(config):
    client = Client(config["helper"], writes=True)
    try:
        client.initialize()
        assert client.call("list_reminder_lists")["result"]["isError"] is True
        native_step("Click Allow Sample Connection, then Return.")
        list_id = data(client.call("list_reminder_lists"))["lists"][0]["listId"]
        return client, list_id
    except BaseException:
        client.close()
        raise


def approve_create(client, list_id, title):
    token = data(client.call("propose_reminder_change", operation="create", targetId=list_id, title=title))["actionId"]
    native_step("Review " + title + " and click Approve Exact Sample Change, then Return.")
    return token


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bin-dir", type=Path, required=True)
    parser.add_argument("--interactive-native-approval", action="store_true", required=True)
    args = parser.parse_args()
    os.umask(0o077)
    with tempfile.TemporaryDirectory(prefix="sample-recovery-", dir=Path(".build").resolve()) as temporary:
        root = Path(temporary)
        canary = root / "synthetic-outside-container.txt"
        canary.write_text("synthetic sandbox denial canary")
        package(args.bin_dir.resolve(), root / "package", canary, profile="sample-writes")
        with session(root / "package") as config:
            print("APP " + config["app"], flush=True)
            native_step("Select Sample list and Enable Sample Changes, then Return.")
            client, old_list = paired(config)
            try:
                applied = approve_create(client, old_list, "Synthetic before crash")
                assert data(client.call("commit_reminder_change", actionId=applied))["status"] == "applied"
                pending = approve_create(client, old_list, "Synthetic uncommitted at crash")
                # Exact task-owned service; a process crash must not turn a previous approval into a replay.
                launchctl("kill", "SIGKILL", f"gui/{os.getuid()}/{config['service']}")
                assert client.call("commit_reminder_change", actionId=pending)["result"]["isError"] is True
                print("PASS sample broker crash closes the old helper channel", flush=True)
            finally:
                client.close()
        # Same signed package and installation UUID. No rebuild, journal edit or container deletion.
        with session(root / "package") as config:
            print("APP " + config["app"], flush=True)
            native_step("Inspect Sample Recovery: confirm 1 applied / 0 unresolved and no selection. Then select Sample list and Enable Sample Changes; Return.")
            client, list_id = paired(config)
            try:
                for token in [applied, pending]:
                    assert data(client.call("commit_reminder_change", actionId=token))["status"] == "notApproved"
                assert client.call("propose_reminder_change", operation="create", targetId=old_list, title="Foreign old list")["result"]["isError"] is True
                assert not data(client.call("search_reminders", listIds=[list_id], fields=["title"], query="Synthetic before crash", limit=5))["reminders"]
                disconnected = approve_create(client, list_id, "Synthetic uncommitted at disconnect")
            finally:
                client.close()
            native_step("Confirm Session stopped and 1 applied / 0 unresolved. Prepare Fresh Sample Session: confirm selection reset, select Sample list and Enable; Return.")
            client, fresh_list = paired(config)
            try:
                assert data(client.call("commit_reminder_change", actionId=disconnected))["status"] == "notApproved"
                assert client.call("propose_reminder_change", operation="create", targetId=list_id, title="Foreign disconnected list")["result"]["isError"] is True
                fresh = approve_create(client, fresh_list, "Synthetic fresh approved session")
                assert data(client.call("commit_reminder_change", actionId=fresh))["status"] == "applied"
                assert data(client.call("commit_reminder_change", actionId=fresh))["status"] == "notApproved"
                native_step("Stop Sample Connection; inspect recovery with 2 applied / 0 unresolved and its operation rows, then Return.")
                assert client.call("list_reminder_lists")["result"]["isError"] is True
                print("PASS same-package crash recovery, fresh native pairing/selection, no old approvals/handles/replay and disconnect recovery", flush=True)
            finally:
                client.close()
    print("PASS task-owned package, canary, keychain and launchd cleanup; sample operation journal remains in its own container", flush=True)


if __name__ == "__main__":
    main()
