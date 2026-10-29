# MacHandle
A privacy-first macOS app for connecting, managing, and syncing calendars, reminders, notes, and contacts across services. You control what's shared, accessed, or modified. Also supports AI agents.


> **Development status:** the description above is the product vision. The native app offers
> separate opt-in Calendar, Reminders and Contacts reads. Synchronization, approval and local MCP
> modules have synthetic test coverage; live Google sync, external MCP access and Apple writes
> remain gated. Signed/provider and real-account acceptance are still required. See
> [implementation evidence](docs/implementation/progress.md) for exact capabilities and limits.
>
> **Apple Notes is experimental and unavailable.** Reading and editing remain deferred after the
> [feasibility review](docs/architecture/decisions/0031-notes-feasibility.md). This build does not
> access Notes or request Notes permission. An [isolated test plan](docs/development/notes-feasibility.md#isolated-runtime-gate)
> preserves the path to proving a safe subset; it has not been run. Do not use personal notes as
> development fixtures. Potential read support and editing require separate evidence.

Remote MCP access is unavailable. The [remote decision and acceptance plan](docs/development/remote-mcp.md)
records a private-tunnel candidate and the authentication, signed broker and client proof still needed.
No listener, tunnel, remote credential or mandatory cloud backend is added. Local development can
continue without remote setup; [account preparation](docs/development/remote-mcp.md#accounts-and-permissions-to-prepare-later)
is for a separately authorized isolated experiment.

## Build and validate

For either Mac, follow [second-Mac setup and branch handoff](docs/development/setup.md).
Open `MacHandle.xcodeproj` in the baseline Xcode and select the shared `MacHandle` scheme.
For a credential-free command-line build and synthetic tests:

```sh
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

Full Xcode **27.1 (27A9275)**, bundled Swift **6.4**, and macOS SDK **27.0** are
required for the shared work/home/CI baseline in `Config/Toolchain.env`.
`DEVELOPER_DIR` can select its installed location per process. The implementation target is macOS 14;
oldest-OS runtime compatibility remains a provider/release verification gate. Unsigned validation
builds are not distribution artifacts. See [testing](docs/development/testing.md).

## Project documentation

- [Documentation index](docs/README.md) and [master implementation plan](plans/MacHandleMasterImplementationPlan.md)
- [Full product specification](docs/product/master-spec.md) and [31-PR roadmap](docs/implementation/pr-roadmap.md)
- [Work-package / GitHub PR mapping](docs/implementation/pr-roadmap.md#work-packages-and-github-prs)
- [Implementation evidence](docs/implementation/progress.md) and [active PR / next action](docs/implementation/pr-coordination.md)
- [Implemented architecture](docs/architecture/overview.md)
- [Contributor instructions](CONTRIBUTING.md) and [agent instructions](AGENTS.md)
- [Security policy](SECURITY.md) and [privacy](PRIVACY.md)
- [Developer accounts, keys, permissions and activation](docs/development/google-auth-setup.md)
- [Release policy](docs/releases.md)

The original repository and [Apache-2.0 license](LICENSE) are retained. Development
uses one focused PR at a time. The maintainer reviews and merges each PR before
the next milestone begins.

Diagnostics now shows coarse current app state and recovery navigation, with a previewable local
support report containing fixed status/capability codes only. Activity remains sample history, not
a provider audit. See the [scoped security review](docs/development/diagnostics-security-audit.md)
for fixed findings and remaining signed/provider/accessibility gates. No production-readiness claim.

Local [release-engineering rehearsal](docs/development/release-engineering.md) now builds a clean
committed snapshot and verifies a development ZIP/manifest/checksums. It never signs, notarizes,
launches or publishes the app. [Account preparation](docs/development/account-release-checklist.md)
and [release policy](docs/releases.md) explain what remains needed; no public release is available.

ChatGPT integration is also unavailable in this build. The [distribution decision](docs/development/chatgpt-distribution.md)
records supported platform paths and the native bridge, eligibility and client acceptance still needed.
The last numbered package delivers this readiness decision; [remaining activation work](docs/implementation/activation-backlog.md)
is separate from roadmap completion. No plugin installation or recurring-task support is claimed.
