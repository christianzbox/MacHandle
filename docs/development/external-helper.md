# External helper fixture and identity checks

This is the account-free portion of [private testing slot 1](../implementation/prs/private-reminders-slot-1.md).
It uses only fixed synthetic reminders. It does not access Apple accounts, iCloud, permissions,
Keychain, developer certificates or personal content. The native app and existing synthetic MCP server
remain unchanged. The two new executables are development probes, not installable product components.

## Run the explicit process check

Select the pinned toolchain per [setup](setup.md), then from the repository root:

```sh
bash Scripts/check_environment.sh
xcrun swift build -Xswiftc -warnings-as-errors
python3 Scripts/test_external_bridge.py \
  --bin-dir "$(xcrun swift build --show-bin-path)" \
  --allow-temporary-launch-agent
```

The last command explicitly opts into temporary GUI-session launchd registration. It copies and ad-hoc
signs fixture binaries in its private temporary directory; originals and signing settings are unchanged.
No paid Apple membership is needed. It never invokes automatic signing, searches identities or accesses
an employer team. Its `dev.machandle.fixture.<random>` service has no KeepAlive or login persistence.
Normal completion and exceptions remove its job and files. A killed harness may require
`launchctl bootout gui/$(id -u)/<exact-fixture-label>`; use only the label from that run's plist, never
wildcard cleanup. The broker self-exits after 60 seconds but exit alone does not unregister its job.
An active GUI login session is required; an SSH/CI-only context can fail bootstrap.

Passing checks cover external selected-list reads, field projection, native-authority separation,
unapproved denial, no per-launch approval reuse, both peer code hashes/identifiers, rejection before
broker dispatch, broker absence/termination and cleanup. Failures print no resource payloads or
provider errors. The broker's temporary marker contains only `sample-channel`, never request contents.

The normal three repository gates still apply. They compile both fixture executables and run unit/
boundary checks, but **do not** register a launch agent. Hosted CI does not run the opt-in process
harness. Report this additional local runtime result separately, on the same final commit.

## What the proof does not establish

The probe carries the native read envelope, not MCP JSON-RPC; do not install it in a client.
The fixture broker makes a harness-local sample approval decision; it has no consent UI or real
provider. Both executables are unsandboxed SwiftPM probes. Current-host success is not minimum-OS,
packaged app sandbox, a validated private-build identity strategy, TCC ownership or actual-client proof.
Those remain slot 1 acceptance gates under [ADR-0037](../architecture/decisions/0037-external-helper-identity.md).
The caller-supplied fixture hash/identifier configures sample-only peers and grants no product authority.
A production configuration must be trusted app packaging; it cannot accept client-supplied peer policy.

## Intended desktop client route

Official OpenAI documentation checked 2026-10-30 describes
[local desktop MCP configuration](https://learn.chatgpt.com/docs/extend/mcp): Settings → MCP servers →
Add server → STDIO, with a local command. This is the preferred private test route once the actual MCP
relay and app pairing exist. Documentation establishes a supported configuration mechanism, not this
account's eligibility, installed surface behavior or MacHandle compatibility. No client configuration,
plugin installation, personal config edit or restart was performed for slot 1.

[Local plugin marketplaces](https://developers.openai.com/plugins/build/plugins) provide a packaging
route if needed later. They are separate from public directory submission. Neither public review nor
remote/tunnel infrastructure is part of the private Reminders finish line. The existing
[distribution matrix](chatgpt-distribution.md) retains public/remote restrictions and owned gates.

MacHandle is a personal app for now. Evaluate owner-controlled local signing before paid enrollment;
public distribution and monetization are outside the private finish line. Employer-team access is not
a personal paid membership. Apple's [account overview](https://developer.apple.com/help/account/basics/about-your-developer-account/)
explains free registration, Personal Teams and multiple team membership. The
[paid program](https://developer.apple.com/programs/) is USD 99/year, but no enrollment is needed to run
these checks. Do not create accounts, register identifiers or use company signing resources as a side
effect of running them. Keep future setup steps in the [account checklist](account-release-checklist.md).
