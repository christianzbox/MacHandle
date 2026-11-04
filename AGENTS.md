# MacHandle engineering instructions

MacHandle is a native, privacy-first macOS app for managing selected Apple resources,
optional Google synchronization and authorized MCP connections. These are product
goals; use progress below to distinguish implemented functionality from plans.

## Read the minimum relevant context

1. Read [PR coordination](docs/implementation/pr-coordination.md) and
   [progress](docs/implementation/progress.md); inspect Git status and the GitHub PR.
2. Follow the active row in the [PR roadmap](docs/implementation/pr-roadmap.md)
   to its focused brief and relevant architecture/ADRs and specification sections.
3. The [master plan](plans/MacHandleMasterImplementationPlan.md) governs execution;
   the [complete product specification](docs/product/master-spec.md) owns requirements.
   Do not load the entire specification for every PR or replace it with a summary.
   [Documentation roles and path map](docs/README.md) prevent competing sources.

## Focused PR workflow and handoff

Fetch origin and preserve user changes. Resume an open PR on its existing branch;
fast-forward before editing. For genuinely new authorized work, verify prerequisite
PRs merged on GitHub, then create one focused `codex/` branch from current main.
A checked box, successful test, or implementation branch is not merge evidence.

Refer to roadmap steps as "work package NN" and reserve "GitHub PR #N" for actual
pull requests. Use descriptive GitHub PR titles without a roadmap PR-number prefix.
Keep legacy PR-NN specification IDs, brief paths and anchors stable for traceability.

Implement one work package. Update its brief, roadmap status, progress/evidence,
coordination/next action, and affected architecture/ADRs in every PR. Record
meaningful decisions with alternatives, tradeoffs, constraints and consequences.
Keep planned, in-progress, implemented, verified, deferred and merged facts distinct.
Deferrals need a reason, owner and revisit trigger; never silently drop requirements.

Review and stage intended files, validate, commit, push, open/update the existing PR,
and stop for user review. Never merge, enable auto-merge, publish, or begin the next
PR automatically. After user merge, verify the actual merge SHA and record it in
the next authorized PR; do not push bookkeeping directly to main.

To avoid redundant hosted builds and keep review feedback focused,
keep implementation/checkpoint PRs draft while iterating. Actually execute all
three full local gates below before the final review push; do not merely list
commands, rely on an earlier revision's results, or substitute hosted CI for
local testing. Record the tested revision, toolchain, commands, pass/fail/skip
results and any blockers in the PR. A toolchain-mismatch run remains supplemental.
Do not claim merge readiness with failed, skipped or unrun required tests.

After local validation and the final push, mark the PR ready for review to start
both full hosted checks. Merge readiness also requires both hosted checks to
pass on the current revision; local success alone is insufficient. If more
iteration is needed, convert it back to draft before pushing checkpoints. Ready
PR updates rerun both checks; draft jobs allocate no runners, and merges do not
trigger a duplicate run. Compiler caches may reuse matching compilation work, but every validation command
and test must still run; never skip a gate on a cache hit. Optional main cache
warming is manual, not a new automatic post-merge run. Budget savings come from
fewer redundant runs and reusable compilation, never
from removing tests or weakening required checks. See
[testing](docs/development/testing.md).

Before changing Macs/sessions, push a safe checkpoint and record remaining work,
checks and next action in Git/PR context. One active writer per branch; never
force-push away the other Mac's changes. Chats, stashes and unpushed commits do not
transfer. Follow [setup and Git handoff](docs/development/setup.md) on either Mac.
Do not commit machine paths, signing teams, credentials or personal Codex state.

## Focused iteration and visual review

While editing, run the affected tests with the pinned toolchain rather than all
builds after every small change. Expand to callers and shared dependencies when
behavior crosses modules. A focused pass is not full validation: all three local
gates and both current-revision hosted checks above remain mandatory before merge.
See [focused commands](docs/development/testing.md#focused-checks-while-editing).

Keep new regression tests small, deterministic and tied to meaningful behavior.
Use synthetic fixtures, injected clocks and controlled dependencies. Preserve
permission, revocation, approval/replay, privacy, mutation/recovery and persistence
contracts at every distinct boundary; similar provider tests are not automatically
redundant. Never delete a failing test to obtain a pass. Temporary stress/visual
investigations may be removed after passing on the final implementation and
recording their recipe/results, once enduring regressions have maintained coverage.
Retiring an existing test requires a documented coverage justification. Measure
material runtime increases; a timing target never authorizes skipping a check.

For visible changes, inspect affected native screens with synthetic data before
review: a representative normal and compact window size, changed controls and
keyboard/focus behavior, and appearance or accessibility settings relevant to the
change. Exercise changed animations/transitions and relevant reduced-motion behavior.
Review shared components on representative affected screens, not every screen/state.
Inspect rendered UI or screenshots; automated assertions alone are not visual review.
Keep this a brief local pass, expanding only for the change or an observed issue;
documentation-only/nonvisual changes need no UI review or new UI automation job.
Use an existing account-free sample or authorized synthetic harness; never enable
live providers, request real-data permissions or alter a private installation just
for this review. Record revision, app/sample, screens, window sizes, relevant settings,
results and limitations in the PR. Fix observed regressions and report unavailable
review explicitly; synthetic UI review is not live-provider or real-device proof.
See [visual review](docs/development/testing.md#focused-native-visual-review).

## Architecture and security invariants

- Use native SwiftUI, Swift 6 language mode, structured concurrency and explicit
  dependencies. Create cohesive modules only when needed. Domain contracts cannot
  import SwiftUI, EventKit, transport types or SQLite. Providers implement contracts.
- Connections start disabled; request each macOS permission only on user opt-in.
  OS authorization, connection policy and trusted local approval are separate.
- Every privileged operation checks identity, resource selection, operation, visible
  fields, approval, revocation and current mutation preconditions in trusted code.
  Caller assertions and resource text cannot confer authority.
- Sync receives source-calendar reads only. Incomplete reads never authorize
  destructive reconciliation. Google sync and MCP must work independently.
- Future secrets use Keychain. No real content, exports, databases, private keys,
  sensitive logs or screenshots in Git; use synthetic fixtures and review every diff.
- No unauthenticated remote listener, private Apple APIs or internal database access.
  Notes remains experimental until its feasibility gate. Do not claim working
  integrations, security guarantees or production readiness without scoped evidence.
- Preserve LICENSE, repository identity/visibility/protections. CI uses read-only
  tokens, immutable action references and no release credentials. Do not weaken checks.

## Build and validate

From the repository root, with intended files staged:

```sh
bash Scripts/check_environment.sh
bash Scripts/validate.sh
bash Scripts/scan_secrets.sh
```

`Config/Toolchain.env` pins Xcode/Swift/SDK. Before changing that baseline, verify
that the exact release build is already preinstalled on the chosen GitHub runner
and supported on both Macs. Keep newer local Xcode versions alongside the baseline;
an App Store update does not authorize a pin change. CI selects preinstalled Xcode
without downloading/installing it. Recheck availability on upgrades or preflight
drift, then require full strict local and current-revision hosted passes.
Selection is per process; use local
`DEVELOPER_DIR` for custom locations. Do not install Xcode or change global selection
automatically. A toolchain-mismatch override is supplemental only, never CI parity.
Validation lints formatting, builds/tests SwiftPM, builds Debug/Release and analyzes
Xcode, tests preflight/privacy checks, and scans indexed files. Secret scanning
uses a checksum-pinned tool on history/index; never print suspected secret values.
Report exact snapshot, results and limits separately for local, hosted and live
behavior. See [testing](docs/development/testing.md). No scanner proves data absence.
