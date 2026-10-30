#!/usr/bin/env python3
"""Native acceptance of one prebuilt Release sample installation; no desktop settings or live providers."""
import argparse
from pathlib import Path

from private_test_install import verify
from run_private_sample import session
from test_private_bridge import Client, native_step
from test_sample_writes import data


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--installation", type=Path, required=True)
    parser.add_argument("--interactive-native-approval", action="store_true", required=True)
    args = parser.parse_args()
    root = args.installation.absolute()
    before = verify(root)
    for number in (1, 2):
        with session(root / "package") as config:
            print("APP " + config["app"], flush=True)
            native_step(f"Inspect Sample Recovery: expect {number - 1} applied / 0 unresolved with access off. Select Sample list and Enable, then Return.")
            client = Client(config["helper"], writes=True)
            try:
                client.initialize()
                assert client.call("list_reminder_lists")["result"]["isError"] is True
                native_step("Click Allow Sample Connection, then Return.")
                list_id = data(client.call("list_reminder_lists"))["lists"][0]["listId"]
                if number == 2:
                    assert data(client.call("commit_reminder_change", actionId=old_token))["status"] == "notApproved"
                    assert not data(client.call("search_reminders", listIds=[list_id], fields=["title"], query="Installed sample", limit=5))["reminders"]
                token = data(client.call("propose_reminder_change", operation="create", targetId=list_id, title=f"Installed sample {number}"))["actionId"]
                assert data(client.call("commit_reminder_change", actionId=token))["status"] == "notApproved"
                native_step(f"Approve exact Installed sample {number} create in native UI, then Return.")
                assert data(client.call("commit_reminder_change", actionId=token))["status"] == "applied"
                assert data(client.call("commit_reminder_change", actionId=token))["status"] == "notApproved"
                found = data(client.call("search_reminders", listIds=[list_id], fields=["title"], query="Installed sample", limit=5))["reminders"]
                assert len(found) == 1 and found[0]["fields"]["title"]["value"] == f"Installed sample {number}"
                old_token = token
                native_step(f"Stop Sample Connection; inspect {number} applied / 0 unresolved, then Return.")
                assert client.call("list_reminder_lists")["result"]["isError"] is True
            finally:
                client.close()
        assert verify(root) == before
        print(f"PASS installed Release session {number}, exact native effect/replay/revocation, immutable package identity", flush=True)
    print("PASS same-installation restart retains journal, resets selection/sample content and denies old approval. No desktop config or iCloud touched.", flush=True)


if __name__ == "__main__":
    main()
