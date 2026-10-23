# MacHandle engineering instructions

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

Implement one work package. Update its brief, roadmap status, progress/evidence,
coordination/next action, and affected architecture/ADRs in every PR. Record
meaningful decisions with alternatives, tradeoffs, constraints and consequences.
Keep planned, in-progress, implemented, verified, deferred and merged facts distinct.
Deferrals need a reason, owner and revisit trigger; never silently drop requirements.

Review and stage intended files, validate, commit, push, open/update the existing PR,
and stop for user review. Never merge, enable auto-merge, publish, or begin the next
PR automatically. After user merge, verify the actual merge SHA and record it in
the next authorized PR; do not push bookkeeping directly to main.

Before changing Macs/sessions, push a safe checkpoint and record remaining work,
checks and next action in Git/PR context. One active writer per branch; never
force-push away the other Mac's changes. Chats, stashes and unpushed commits do not
transfer. Follow [setup and Git handoff](docs/development/setup.md) on either Mac.
Do not commit machine paths, signing teams, credentials or personal Codex state.

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

`Config/Toolchain.env` pins Xcode/Swift/SDK. Selection is per process; use local
`DEVELOPER_DIR` for custom locations. Do not install Xcode or change global selection
automatically. A toolchain-mismatch override is supplemental only, never CI parity.
Validation lints formatting, builds/tests SwiftPM, builds Debug/Release and analyzes
Xcode, tests preflight/privacy checks, and scans indexed files. Secret scanning
uses a checksum-pinned tool on history/index; never print suspected secret values.
Report exact snapshot, results and limits separately for local, hosted and live
behavior. See [testing](docs/development/testing.md). No scanner proves data absence.
