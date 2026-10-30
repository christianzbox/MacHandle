# Private Reminders slot 1 — external helper and identity

Review: [GitHub PR #34](https://github.com/christianzbox/MacHandle/pull/34).
Branch: `codex/external-helper-identity`. Status: account-free implementation for review;
**full slot 1 acceptance remains open**. This is a private-testing slot, not work package 32 or a
GitHub PR number. The [master plan](../../../plans/MacHandleMasterImplementationPlan.md#reminders-private-testing-finish-line)
owns the six-slot scope and finish line.

Dependency verified: GitHub PR #33 merged at `94df5e5b1654268d711f4cd2bf498163e73e028d` on
2026-10-30 14:10:42 UTC. Both hosted checks passed on `88b5de8bc351fca45dc50efd38247bbeee28cd46`.
User authorized one slot 1 review PR, sample data only, personal iCloud untouched. The app is for personal use for now; paid enrollment/public distribution are outside the current
scope and employer signing resources are excluded. No merge or following slot authorized.

## Scope and decisions

Implement actual external process discovery and mutual signature checks with account-free fixtures,
retaining the existing native broker's read/approval policy. Separate the minimal transport probe from
the sample broker and preserve provider/credential isolation. Verify wrong identities before dispatch,
absence, closure, unapproved access and per-launch separation. Record the intended desktop client route
and the unresolved deployment gates. [ADR-0037](../../architecture/decisions/0037-external-helper-identity.md)
records alternatives and consequences; the [runbook](../../development/external-helper.md) owns commands.

This PR does not install the helper in a client, register a persistent service, change app entitlements,
request permission, create an account, sign with a certificate or touch real Apple data. The external
probe uses the native read envelope; it is not yet the product MCP relay. The sample broker's explicit
harness decision is not user consent. Existing native sample UI and synthetic stdio MCP remain intact.

## Implementation and acceptance

Implemented: validated code-hash/identifier and Apple-team/identifier requirement constructors,
requirements installed before XPC resume, content-free verified handshake before each read, transport-owned per-channel authentication gate, bounded
single-channel read transport, independently launched probe/broker, reused filtered native broker,
opt-in temporary launchd harness, fixed rejection markers and checked cleanup. Team requirement syntax
is tested; actual team-signed acceptance is not.

Staged gates passed before final documentation/harness cleanup polish: environment 0.39 s, validate
103.10 s, secret scan 2.42 s. Validation passed 457 Swift tests (three new), 32 Python checks, 55
expected compiler rejections, SwiftPM/native Debug/Release/analyzer and privacy checks. Documentation
check passed 1,425 local links/anchors and all 31 roadmap anchors; protected files and app entitlements
are unchanged. The external process harness passed on macOS 27.2 using task-owned ad-hoc copies.
Exact final-head repeats and hosted results belong in the review PR. Hosted CI runs the normal gates,
not temporary service registration. No packaged sandbox or actual-client acceptance was performed.

| Acceptance | State / owner / revisit trigger |
| --- | --- |
| Real process discovery + mutual identity rejection | Verified locally for unsandboxed ad-hoc fixture copies on current OS; final-head repeat required before handoff. |
| Policy denial, selected synthetic reads, per-launch isolation, broker absence/termination | Verified by fixture harness; native UI tests remain separate. |
| Supported desktop local configuration mechanism | Official documentation verified; actual account/surface/install acceptance deferred to isolated client setup. |
| Sandboxed app discovery, native approval handoff, real MCP relay | Open, engineering; resolve reviewed packaging/composition before provider activation. |
| Owner-controlled private-build identity and minimum/current OS package | Open, engineering + maintainer; evaluate an account-free local signing route and isolated runtime evidence. An unclosed gate does not establish a need for paid enrollment. No employer credentials. |

This delivers the account-free portion, **not completed slot 1 or private-test readiness**. Stop at
review. Before another implementation PR, explicitly resolve/re-scope these gates and any effect on
the six-slot PR estimate with the user; do not quietly append work or advance to slot 2.
