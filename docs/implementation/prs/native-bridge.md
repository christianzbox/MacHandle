# Native bridge — sample pairing and read transport

Authorized follow-up after the original 31-package roadmap. Prerequisite GitHub PR #32 merged at
`34ad4c3e4e0165123cda48b9b3808adab8e7fd36` on 2026-10-29 16:52:36 UTC. Branch:
`codex/native-bridge-sample-pairing`. No inferred package 32 or release milestone.
Review: [GitHub PR #33](https://github.com/christianzbox/MacHandle/pull/33).
Merged 2026-10-30 14:10:42 UTC at `94df5e5b1654268d711f4cd2bf498163e73e028d`; verified in the next authorized slot 1 PR.
Implementation checkpoint: `59aa15c71532963a00b6c636c822afa8cd57b3fe`, pushed.

## Scope and requirements

Connect native local review to the existing connection controller, policy-filtered Reminders reads
and an actual anonymous XPC request/reply path using fixed fixtures. Preserve specification §8,
ADR-0006/0024 authority boundaries, default denial, one-time expiring review and revocation checks.
No personal iCloud, permission grants, live providers, signing, external helper activation or remote
listener. No writes, durable state, client install or publication. Retain all signed/runtime gates.

## Implementation and acceptance

[ADR-0036](../../architecture/decisions/0036-native-bridge-sample-pairing.md) records decisions,
alternatives and remaining gates; [developer checks](../../development/native-bridge.md) explain
manual sample controls and automated coverage. NativeMCPBridge owns trusted broker composition;
MacHandleApplication exposes only a fixed sample model to SwiftUI. Package visibility changes reuse
existing parser/tool/adapter/fixture contracts without making controller or grant APIs public.

Implemented: strict bounded read envelope, native-only pairing review, connection-bound adapter,
selected synthetic list/title/completion grants, anonymous XPC transport, cancellation/deadline/
invalidation, UI clear-on-stop and fresh-review behavior. No helper launch or external peer is claimed.

Staged gates passed before final documentation polish: environment 0.23 s, validate 59.78 s,
secret scan 1.65 s. Validation ran 454 Swift tests (nine new), 32 Python checks, 53 expected compiler
rejections, SwiftPM builds, native Debug/Release/analyzer, formatting and privacy checks. All 1,399
local documentation links/anchors and all 31 original roadmap anchors passed; license, complete
specification, toolchain, CI and entitlements are unchanged. Native model/XPC behavior was exercised;
interactive app layout and signed sandbox/provider behavior were not. Exact final-head repeats and
hosted results belong in the review PR. No personal-provider testing. Stop for review; do not merge
or begin another activation slice.
