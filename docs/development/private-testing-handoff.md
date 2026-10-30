# Start private sample testing

This is the final handoff for the six-slot **sample Reminders** track. It is a local test build,
not the full live application. It can read Sample list and create, edit, set a due date, complete,
uncomplete and delete simple sample reminders through the desktop client, with native approval.
Calendar, Google sync, Contacts, Notes, personal Reminders/iCloud, remote access and scheduling are
not activated. Real-provider testing needs a separately scoped and authorized isolated environment.

## Accounts, tools and permissions

| Item | Needed for this test? |
| --- | --- |
| Apple Developer membership, employer team, legal entity or D-U-N-S | No |
| Google account/project, OAuth client, API keys or database account | No |
| Existing supported desktop client | Yes, with its local MCP capability; use your existing sign-in, not a new API key |
| Python | 3.11+ on Terminal PATH; `python3 --version` checks it |
| Xcode | Pinned [setup](setup.md) toolchain only to build; the installed test can run without rebuilding |
| macOS Reminders/Calendar/Contacts/Automation permission | None; an unexpected provider permission prompt is a stop condition |

The tested client is ChatGPT desktop's **local Codex chat** surface. Other Chat/Work modes, web/mobile,
other Macs and minimum macOS 14 runtime remain unverified. The tested Mac runs macOS 27.2 on arm64;
builds are one host architecture. Keep the installation on that designated Mac, outside cloud-sync
folders. Do not use an employer signing identity, change system trust or disable Gatekeeper.
Future account choices remain in [account setup](account-release-checklist.md); no purchases now.

## Build once after reviewing the PR

Start from a clean committed checkout of the reviewed code. Preserve your changes first; the builder
refuses dirty source and never overwrites an existing destination. Follow [setup](setup.md) to select
the pinned Xcode per process. Run the normal three gates, then choose a new **final** installation path:

```sh
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
mkdir -p "$HOME/MacHandle-Private-Tests"
bash Scripts/build_private_test.sh "$HOME/MacHandle-Private-Tests/sample-build-01"
python3 -B Scripts/private_test_install.py verify \
  --installation "$HOME/MacHandle-Private-Tests/sample-build-01"
```

Use a physical path without symlinks. This produces a clean-source Release app/helper, a local signing
certificate, a frozen runtime launcher, file hashes/modes and source revision. The signing private key
and temporary keychain are removed. No app starts, client settings change or permission is requested
during build/verify. Signing uses no Apple account. The local certificate's validity period is 365 days;
that is not a promise of indefinite OS/client compatibility. Stop on a later validation failure; retain
the old package/journal for inspection. The lower-level `create` helper accepts asserted provenance;
use the clean-source shell builder for the recorded source relationship.

Keep the entire directory at this path. Copying/moving just the app breaks the bound paths. Rebuilding
creates a different identity; **reuse this installation between sessions**. Reminder contents are
in-memory and reset on restart; the same installation's UUID/status recovery journal persists.
No archive/public distribution, automatic login item or automatic updater is installed.

## Start a testing session

```sh
cd "$HOME/MacHandle-Private-Tests/sample-build-01"
bash "Run Sample.command"
```

This verifies the installed files/signature and explicitly opts into one temporary native job and one
temporary desktop MCP entry. The copied runtime does not follow later repository changes.

1. In **MacHandle Private — Sample Changes**, confirm access is off. Use **Inspect Sample Recovery**;
   a new installation should show zero records. If pending/unknown is present, stop and retain evidence.
2. Select **Sample list**, then **Enable Sample Changes**. Return in Terminal when prompted.
3. Start a fresh local desktop session using the generated server name printed by the launcher.
   It should expose exactly the five tools in the [desktop checklist](private-desktop-client.md).
   If missing, follow the supported client reload/setup route; do not change global sandbox or approvals.
4. Allow the sample helper connection in the native app. The helper signature identifies that helper,
   not a specific AI brand/user. Only approve the session you just started.
5. Ask for one bounded action at a time. Read the native before/after review before approving; each
   write needs its own approval. Commit must follow within 30 seconds. Deletion needs an additional
   unchecked acknowledgement. Client confirmation alone cannot authorize the native change.

Example request for your test chat:

> Use only the MacHandle sample server from this session. Read Sample list and its sample reminders.
> Propose creating “My sample test”; stop for native approval before committing. Never use another
> integration or personal data. If a response is uncertain, stop instead of retrying.

## Pass/fail record for your first session

Keep this record locally. Mark a case passed only after observing its result, not because the feature
exists in source. Record source SHA and client/OS version without personal paths or transcripts.

- [ ] Build/verify succeeds; no account setup or OS permission prompt.
- [ ] Access starts off; no read succeeds before native pairing.
- [ ] Only Sample list is visible; read and exact details return expected sample fields.
- [ ] Create, title edit, date edit, complete and uncomplete each require native approval and read back correctly.
- [ ] Delete requires the extra acknowledgement; readback confirms the created item is absent.
- [ ] Rejected/unapproved actions cannot execute; replaying a used action does not duplicate it.
- [ ] Native Stop denies the same client's next read; journal shows expected applied count and zero unresolved.
- [ ] Terminal cleanup removes only this entry/job; unrelated client entries remain.
- [ ] Reopen **the same installation**: access is off, journal count persists, sample content resets,
      and new selection/pairing/approval is required. Old action IDs cannot be reused.

An error, timeout or lost reply is not proof a change failed. Inspect native recovery and preserve the
journal. Pending/unknown blocks further work. Never rebuild, switch installations or erase records to
make uncertainty disappear. Use the [recovery explanation](private-sample-recovery.md).

## Stop, update and remove

Click **Stop Sample Connection**, disconnect/end this sample client's session, then Return in Terminal.
The launcher removes only its unchanged entry and exact job. It preserves an entry edited by someone
else and reports a manual-inspection error. Avoid concurrent settings edits during add/remove. A cached
client helper may persist until its session ends; native stop/bootout independently revokes access.
Ctrl-C/SIGTERM unwind normal cleanup. For SIGKILL/power loss use the targeted instructions in
[desktop cleanup](private-desktop-client.md#cleanup-and-interruption). Do not remove unrelated entries/jobs.

There is **no in-place update or journal migration** in this private build. After stopping and inspecting
the old installation (zero unresolved required), build a reviewed update in a new sibling directory.
Retain the old installation/journal and record which source belongs to each. A new directory is a new
fixture environment, not continuation or reconciliation of the old data. Rollback means reopening the
old unchanged installation with fresh selection/pairing; no settings/data migration occurs. Never run
two installations together. Long-term signing-key custody/in-place migration needs a separate decision.

After confirming all task-owned processes/jobs and client entries are gone, the installation directory
may be removed. Its OS-managed sandbox container and UUID/status journal intentionally remain. Do not
delete Library/iCloud containers or existing Keychain items. There is no automated data-purge command.

## Engineering evidence and finish line

[Slot 6](../implementation/prs/private-reminders-slot-6.md), [ADR-0043](../architecture/decisions/0043-private-test-installation.md)
and [progress](../implementation/progress.md) record tested snapshots and known limits. Slot 5 provides
actual desktop-client evidence; slot 6 adds clean-source Release build, installation verification and
same-installation native restart acceptance. To reproduce the latter from the matching checkout:

```sh
python3 Scripts/test_private_installation.py \
  --installation "$HOME/MacHandle-Private-Tests/sample-build-01" --interactive-native-approval
```

That harness expects a new installation with zero records and leaves two applied sample receipts;
it uses a protocol probe, not a substitute for the desktop test. Do not rerun it against an installation
with existing evidence. Engineering completion of these six slots means a sample testing handoff;
your checklist acceptance and all live-provider gates remain distinct. No additional slot starts
automatically. Scope/count the real-Reminders phase before authorizing more implementation.
