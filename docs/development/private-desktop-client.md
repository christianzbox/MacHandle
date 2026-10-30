# Private desktop sample acceptance

[Slot 5](../implementation/prs/private-reminders-slot-5.md) and
[ADR-0042](../architecture/decisions/0042-private-desktop-sample-client.md) own this workflow.
Only in-memory sample Reminders are available. No EventKit store, TCC, personal iCloud, developer
account, employer identity, remote endpoint or public publication is involved.

## Prepare and review

Select the pinned per-process toolchain using [setup](setup.md), then:

```sh
xcrun swift build -Xswiftc -warnings-as-errors
python3 Scripts/desktop_sample.py prepare --bin-dir .build/out/Products/Debug \
  --output .build/desktop-sample
```

Choose a new output directory; replacement is refused. Preparation signs the existing sample-writes
app/helper using a disposable local certificate, removes its signing keychain and writes a unique
server name and `client-preview.toml`. Inspect the preview locally: the packaged `machandle-local-mcp`
with exactly `--sample-writes`. Absolute machine paths occur only in ignored output. Preparation never
launches or changes client settings. Do not move the package afterward; its metadata binds these paths.

The [official desktop MCP guide](https://learn.chatgpt.com/docs/extend/mcp) documents Settings → MCP
servers → STDIO and the `codex mcp add NAME -- COMMAND ARGUMENTS` route. Verify installed desktop/CLI
versions and that they use the same configured home. Documentation alone does not prove this account
or session can use the connection. Do not purchase a plan or silently switch clients to close this gate.

## Temporary session

```sh
python3 Scripts/desktop_sample.py run --prepared .build/desktop-sample \
  --allow-temporary-client-config --allow-temporary-launch-agent
```

1. Select **Sample list**, then **Enable Sample Changes** in the native app. Access starts off.
   Unexpected OS permission prompt: stop; this profile has no provider entitlement/purpose strings.
2. Return in the launcher. It adds only its generated `machandle_sample_…` entry through the supported
   CLI. It refuses collisions and checks semantic preservation of unrelated settings without printing
   them. Avoid concurrent settings edits during add/remove; the check is not a global settings lock.
3. Use a new local desktop chat/session or supported client reload. Confirm the server/tools below.
   Do not restart an active work chat automatically. If tools are absent or blocked, retain the actual
   error; do not disable sandbox protections or substitute a Python/CLI protocol probe as client proof.
4. First verify a read is denied before native pairing. Then approve **Allow Sample Connection** in
   the sample app. Pairing permits proposals, never automatic writes.

Client confirmations and native authority are separate. Reviews expire after two minutes; approved
commits expire after 30 seconds. Coordinate native approval with immediate commit. A timeout/lost
reply is not rollback: inspect the journal and never automatically resend an uncertain mutation.

## Actual-client checklist

Use the desktop client's own MCP tools. Keep titles synthetic, such as `Desktop sample new` and
`Desktop sample revised`. Record operation/status/count evidence, not personal chat/config transcripts.

| Step | Required observation |
| --- | --- |
| Discovery | Exactly list_reminder_lists, search_reminders, get_reminder, propose_reminder_change and commit_reminder_change; no approval tool |
| Unpaired / guessed handle | Read before pairing and fabricated target denied without effect |
| Selected reads | One Sample list; returned opaque handles, bounded search, explicit fields and exact item details |
| Rejection | Native Reject Proposal followed by commit returns notApproved |
| Create | Preapproval commit notApproved; exact native approval then commit applied; readback confirms title |
| Update / setDue | Separate proposals, exact native approvals and commits; readback confirms title/date |
| Complete / uncomplete | Separate proposals and exact approvals; readback confirms both states |
| Delete | Separate native deletion acknowledgement and exact approval; one applied commit, then search absent |
| Replay | Reuse each completed action: notApproved and no duplicate effect |
| Revoke | Native Stop Sample Connection; same client read denied; journal six applied, zero unresolved |

Use tool-discovered schemas. Create targetId is a returned listId; other targetIds are returned
reminderIds. Re-search after changes for current handles. actionId comes from each proposal. Never
guess provider IDs, forge approval fields or treat an unexpected/unknown result as successful.

## Cleanup and interruption

Stop the native connection, end/disconnect the sample client session, then Return in the launcher.
It removes only the unchanged owned entry and unloads only the exact temporary launchd job. Ctrl-C
and SIGTERM unwind cleanup too. Removing config may not stop a cached helper in an existing client
session; native stop/bootout independently denies further access.

A changed owned entry is preserved for manual inspection. No stale whole-file backup is restored
over concurrent edits. SIGKILL/power loss cannot run cleanup: inspect generated desktop.json and
package/session.json locally, verify ownership, then remove only that server using
`codex mcp remove NAME` and that job using `launchctl bootout gui/$(id -u)/SERVICE`. Verify both absent.
Never dump full client settings, kill unrelated clients or prune launch agents. Preserve uncertainty
and use [recovery](private-sample-recovery.md); rebuilding is not recovery.

The task-owned package/canary may be removed after cleanup. Its UUID/status journal and OS-managed
sandbox container remain intentionally. Do not delete Library/iCloud containers or existing Keychain
items. Slot 6 owns stable installation/upgrade and final testing handoff.

## Evidence boundary

CI uses synthetic temporary config files and mocked CLI commands; it never signs/launches this app
or edits desktop settings. Actual desktop results, exact source/client versions and cleanup evidence
belong in [progress](../implementation/progress.md) and the review PR. Real provider conflict/TCC,
minimum-OS runtime, other Macs, web/mobile, scheduling and public distribution remain open.
