# Private Reminders slot 1 — external helper and identity

Current branch: `codex/private-slot1-native-relay`. Status: completion implemented for review;
account-free native/MCP sample path verified on the current Mac. No merge or next slot authorized.
The [master plan](../../../plans/MacHandleMasterImplementationPlan.md#reminders-private-testing-finish-line)
owns the finish line. Slot numbers are independent of GitHub PR numbers.

## Prerequisite and scope

GitHub PR #34 merged at `c63bee0419aea526761795fe93f02bf767b282cf` on 2026-10-30
14:46:31 UTC (10:46:31 America/Detroit). Both hosted checks passed on
`3043318987dd3e85005765b6fde96878db3f1de7` in CI run 41073243162. The user authorized finishing
the remainder of slot 1 in one additional review PR, account-free, sample-only, personal iCloud untouched.

The first half, [GitHub PR #34](https://github.com/christianzbox/MacHandle/pull/34), proved separate
process identity with an unsandboxed read-envelope probe. This PR adds the missing packaged native
sandbox/consent path, real MCP relay, owner-controlled local signing, and current-Mac acceptance.
[ADR-0038](../../architecture/decisions/0038-private-native-mcp-relay.md) records alternatives and limits;
the [runbook](../../development/private-native-bridge.md) owns the opt-in commands.

## Implementation and acceptance

Implemented: dedicated sandboxed native sample app, hardened minimal stdio relay, shared read-tool
contract, local certificate + sibling identifier requirements derived from running code, signed bundle
validation, temporary GUI-session registration, existing native controller approval/revocation, and
repeatable packaging/native acceptance scripts. The helper has no provider/policy/approval dependency.
No Apple/employer identity, existing Keychain secret, TCC prompt, persistent install or real provider
is used. Local disposable signing keys and keychains are removed; no trust-store changes occur.

| Acceptance | Evidence / boundary |
| --- | --- |
| Independent helper → sandboxed native broker | Actual packaged XPC check-in works on macOS 27.2 without Mach exceptions or app groups. External synthetic canary read denied. |
| Owner-controlled mutual identity | Local self-signed issuer plus exact sibling identifier; no caller-selected authority; tampered resource and wrong-build helper rejected. Prior separate-direction hash/identifier tests remain maintained. |
| Native per-launch consent and revocation | Real native Allow/Revoke clicks; before-approval and after-revoke MCP calls denied; second launch cannot reuse approval. No hidden approval API. |
| Actual MCP relay | Python stdio client initialized, listed the three read tools, discovered the selected sample list and read title/completion; notes, writes and wire approval denied. |
| Current desktop route | Official local stdio configuration path remains documented; actual ChatGPT/selected desktop application test belongs to slot 5. No client installed/configured now. |
| Version/machine scope | Current designated Mac verified; macOS 14 compiles. Engineering + maintainer retain minimum-OS runtime before expanding machines or compatibility/distribution claims. |

Focused validation passed 459 Swift tests and 55 expected compiler rejections. Native runtime testing
verified approval, filtered reads and revocation. Initial immediate teardown checking raced launchd's
asynchronous removal; the harness now waits a bounded five seconds and reports exact-label failure.
Full staged/final gates and repeated complete native acceptance are recorded in progress/the review PR.

## Finish line and next action

Slot 1 is complete for the agreed **account-free, sample-only path on the current Mac** once this PR is
reviewed/merged; implementation and verification do not imply merge. The earlier brief's minimum-OS/
actual-client references are explicitly assigned to compatibility acceptance/slot 5 under ADR-0038;
no product requirement is silently dropped. Stable identity/update handoff is slot 6, with no paid
membership assumption. Slot 1 has two authorized PRs; five planned slots remain, each initially
estimated as one review PR. Stop here: slot 2 real isolated reads needs separate authorization, and
personal iCloud remains excluded.

Staged validation before final documentation/dispatch polish: environment 0.51 s, validate 62.78 s, secret scan 1.94 s; 459 Swift tests, 32 Python checks, 55 expected compiler rejections, native Debug/Release/analyzer and privacy checks passed. The complete packaged native/MCP acceptance then passed with real Allow/Revoke clicks and confirmed task-owned job/artifact/keychain cleanup. Documentation check passed 1,443 links/anchors and all 31 roadmap anchors; protected files and existing app entitlements are unchanged. Exact final-head repeats and hosted evidence belong in the review PR.
