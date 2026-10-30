# Private selected Reminders acceptance

[Slot 2](../implementation/prs/private-reminders-slot-2.md) and
[ADR-0039](../architecture/decisions/0039-private-selected-reminder-reads.md) define scope.
Use the pinned per-process toolchain from [setup](setup.md). No paid Apple account is required to
build/package. Real account-free EventKit runtime acceptance has **not** been demonstrated.

## Automated and native sample checks

The three normal gates compile the provider composition and run injected-provider/model and packaging
profile checks. They never launch the private app, construct a live EventKit store or request TCC.
Run the separate signed sample acceptance in a GUI session:

```sh
python3 Scripts/test_selected_reminders.py \
  --bin-dir .build/out/Products/Debug --interactive-native-approval
```

The script generates a disposable local signing identity in its own temporary keychain, signs only
its sample app/helper, registers one temporary launchd job, and requires actual UI actions:

1. Load Sample Lists. Confirm no list or field is selected. Choose only **Synthetic selected list**,
   **Title**, and **Completion**, then Start Selected Connection and Return in the terminal.
2. Confirm reads are initially denied. Click Allow Selected Reads, then Return.
3. The client checks list/search/detail, hidden notes/list denial, foreign IDs, unavailable writes and
   no wire approval. Click Stop and Clear Selection, then Return; the same client's next read must fail.

The app uses only injected synthetic objects; its sample profile has no provider entitlement or purpose
key. A task-owned external canary must be sandbox-denied. Temporary package/canary/signing keychains
and launchd jobs are cleaned up. OS-managed private app containers may remain; do not prune Library,
Keychain profiles or iCloud containers. No real Reminder, account, client configuration or permission
is touched. Re-run the existing [slot 1 native acceptance](private-native-bridge.md) and
[external identity checks](external-helper.md) on the final commit as separate regressions.

## Isolated EventKit acceptance — deferred, not run on the personal profile

Engineering/maintainer must separately authorize this section. A specially named list in personal
Reminders is insufficient: EventKit permission can reach that profile's other lists. Use a separate
macOS test user with no Apple ID, Internet Accounts or personal/synced content. Confirm this manually
before any permission request. Do not enumerate personal account settings to establish isolation.

Prepare two local lists and a few clearly synthetic reminders using supported Reminders UI only,
if the OS permits account-free local lists. Include a selected list, an unselected canary list,
titles/completion and notes that should remain hidden. Record setup provenance, never real content.
If local lists are unavailable without an online account, stop: account-free provider acceptance is
blocked. Do not sign into personal iCloud, create online accounts or write private databases.

Only in that authorized environment, package to a new task-owned absolute directory:

```sh
python3 Scripts/package_private_sample.py --bin-dir .build/out/Products/Debug \
  --output "$PWD/.build/isolated-reminders-candidate" --profile isolated-reminders
python3 Scripts/run_private_sample.py --package "$PWD/.build/isolated-reminders-candidate" \
  --allow-temporary-launch-agent --allow-isolated-eventkit
```

Packaging does not launch or request permission. The separate runner opt-in allows the native app to
open; it still requires isolation acknowledgement and **Enable Isolated Reminders**. The UI explains
that Apple grants read/write OS access while MacHandle exposes reads only. Local signing/TCC behavior
is an acceptance question, not a guarantee. Never disable sandbox/signature checks to make it work.

Record commit, OS/toolchain, profile, local identity kind (no private keys) and each outcome:

| Check | Required result |
| --- | --- |
| Launch before enable | No permission prompt, discovery, data, automatic selection or connection approval |
| Deny permission | No lists/read results; no fallback to the sample provider |
| Grant via explicit native enable | Discover only the isolated account's synthetic inventory; no list or field selected automatically |
| Select one list and title/completion | Start Selected Connection; configure a task-owned protocol probe with the printed helper command (`--private-reminders`), not the actual desktop client yet |
| Before native approval | All data reads denied |
| After native approval | `list_reminder_lists`, `search_reminders`, `get_reminder` return only granted selection/fields; local-cache/incomplete observations remain explicit |
| Negative scope | Unselected list/foreign ID, notes and write/approval names denied; no provider writes occur |
| Revoke OS permission / change list | Pending/next reads fail; foreground/store change clears selection and closes access; no stale result becomes authority |
| Native stop / helper disconnect | Existing client denied; restart needs fresh selection and approval |
| Cleanup | Stop client; Return in runner removes exact temporary job; quit test app; remove only task-owned package and manually created synthetic fixtures in the isolated account |

Any failure remains an open gate with evidence and owner. Do not claim cloud freshness, minimum-OS
runtime support, actual ChatGPT integration or full private-test readiness from these sample checks.
Stable identity/upgrade setup is slot 6; actual desktop-client workflow is slot 5.
