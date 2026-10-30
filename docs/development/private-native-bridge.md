# Private native app and MCP relay acceptance

[Slot 1](../implementation/prs/private-reminders-slot-1.md) finishes the account-free native bridge
on the current Mac. [ADR-0038](../architecture/decisions/0038-private-native-mcp-relay.md) owns its
identity, sandbox and scope decisions. Only fixed synthetic Reminders are available. The regular
app, personal iCloud, Apple/Google accounts and provider permissions are not used.

## Build and exercise the native sample path

Select the pinned toolchain per [setup](setup.md), then from the repository root:

```sh
bash Scripts/check_environment.sh
xcrun swift build -Xswiftc -warnings-as-errors
python3 Scripts/test_private_bridge.py \
  --bin-dir "$(xcrun swift build --show-bin-path)" \
  --interactive-native-approval
```

This is an explicit opt-in integration test, separate from normal CI. It generates a disposable local
certificate/keychain, signs sample app/helper artifacts, and temporarily bootstraps a GUI-session job.
No Apple enrollment or existing signing identity is required. A GUI login session is required.
When prompted, click **Allow Sample Reads** in the named MacHandle Private sample window, then press
Return in the test terminal. After the next prompt, click **Revoke Sample Access**, then press Return.
Complete each review step within 55 seconds. There is no automatic or remote approval API.

The harness checks:

- Missing broker and a tampered signed resource fail without fallback.
- A differently signed build cannot claim the listener before the intended helper.
- The three read-tool schemas are exposed; initial reads and wire approval are denied.
- A real native click enables only selected sample list/title/completion reads.
- Notes, write tools, a second helper launch and a different issuer remain denied.
- Native revocation denies the same MCP client; closing the session removes the launchd job.
- The app cannot read a synthetic canary that the unsandboxed test can read outside its container.

Checks use a Python MCP client, not ChatGPT. It verifies the actual local stdio/XPC/native path using
the existing legacy protocol. Normal protocol tests retain modern/legacy framing and validation
coverage. Actual desktop application installation/interoperability remains slot 5.

The harness removes its task-owned artifacts, canary and signing keychains and waits up to five
seconds for launchd teardown before checking absence. macOS may retain containers for the unique
sample bundle identifiers; these are separate from personal iCloud containers. The test does not
prune Library directories. Forced termination can interrupt cleanup: use the **exact** fixture label
from that run's `session.json` or error, `launchctl bootout gui/$(id -u)/<exact-label>`, never broad pruning.
No private key, password, certificate export or personal content belongs in Git or test output.

## Optional reusable sample session

To produce a sample artifact for a separately authorized manual/client rehearsal:

```sh
python3 Scripts/package_private_sample.py \
  --bin-dir "$(xcrun swift build --show-bin-path)" --output /tmp/machandle-private-rehearsal
python3 Scripts/run_private_sample.py \
  --package /tmp/machandle-private-rehearsal --allow-temporary-launch-agent
```

The output directory must not exist. Packaging does not launch or install anything. The session
command prints a local MCP command/argument pair and waits; Return stops/unregisters it. The app
launches when the helper connects, then requires native approval. No client config is edited. Each
packaging run has a new local issuer and bundle identifier family; the discarded private key means
this is not an upgrade/signing-continuity scheme. Rebuild after changes, and retain no pairing across
builds or launches. Slot 6 will define the durable private-testing build/install handoff.

The app is sandboxed and hardened; the minimal helper is hardened but unsandboxed. No special helper
entitlements, global Mach lookup exceptions, app groups, network listeners or service-at-login
registration are added. A sandbox imposed by the eventual AI client can still deny the helper's IPC;
handle that as actual-client evidence, never silently widen privileges.

## Validation and limits

Run the three normal repository gates with intended changes staged. CI compiles the new executables,
runs unit/schema/boundary/privacy checks, and builds/analyzes the regular app. It does not create local
identities, register services or click native UI. Run the opt-in acceptance on the same final commit
and report local, hosted and native runtime evidence separately.

The evidence is macOS 27.2 on the current designated Mac, with macOS 14 deployment compilation only.
Minimum-OS runtime remains an owned compatibility gate before expanding machines/claims. No EventKit,
Contacts, Notes, Google, existing personal Keychain items, real Reminders or personal permission state are tested.
The self-signed artifact is not notarized, App Store approved or a public distribution package. Paid
membership and monetization remain future choices, not assumptions for this private work.
