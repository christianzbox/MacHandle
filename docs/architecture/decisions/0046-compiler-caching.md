# ADR-0046: Compiler caching without reducing validation

Date: 2026-11-03. Status: implemented for review in GitHub PR #42; exact-revision measurements in the PR.

## Context and decision

The maintainer requested faster hosted builds with the same testing coverage.
GitHub PR #41 merged at `940d1a03d136f7056f49d85bf9b9daa837979e6a` on
2026-11-03 17:05:52 UTC. Its last uncached macOS job took 8m 44s, including
roughly 4m 40s for Debug/Release builds and analysis. Retain its local-first,
draft/ready cadence, strict toolchain checks and both required hosted jobs.

Enable Xcode's supported compilation cache in the shared validation commands,
using a repository-local .build/compilation-cache directory. The compiler keys
results by compilation inputs; changed inputs are compiled normally. Diagnostic
remarks and build timing summaries provide hit/miss evidence. SwiftPM, Xcode
Debug/Release, analyze, all tests, formatting, boundaries, privacy and secret
scanning still execute. No cache-hit condition may skip validation or reuse a
passing test result as evidence for a new run.

Use the SHA-pinned actions/cache action for exactly these compiler-owned paths:

- .build/compilation-cache
- .build/out/ModuleCache.noindex
- .build/out/SDKExplicitPrecompiledModules
- .build/xcode/ModuleCache.noindex
- .build/xcode/SDKExplicitPrecompiledModules

Do not restore the whole .build tree, application/test executables, build databases,
analysis/test reports, arbitrary home directories, signing state or Xcode itself.
Every hosted job has a fresh source checkout and rebuilds its target graph.
Compiler caches are an optimization, not a source of acceptance evidence.

## Compatibility, scope and failure behavior

Verify the exact toolchain before restoring caches. The namespace hashes runner
OS/architecture, actual macOS build, runner image identifiers, selected developer
and checkout paths, exact Xcode/Swift/SDK versions and SDK build. A second hash
covers Config, package manifest/lockfile, Xcode project, validation script and
workflow. A schema prefix permits deliberate invalidation. Each revision gets
an immutable entry; prefix fallback stays inside the same compatibility namespace.
Source changes are handled by the compiler's own input keys, not timestamps
rewritten by a custom restoration script. Save only after a successful build job.
A miss/eviction runs the complete suite cold; a cache hit runs it warm. A build or
test failure remains a failure. Delete suspect cache entries for a clean PR rerun.

GitHub PR caches are scoped to the PR merge ref. To share a cache with future
PRs, a maintainer may run this same full workflow manually on main after merge.
This is optional and consumes one full validation run; it is not automatic after
every merge, scheduled, or a replacement for PR checks. Disable use_cache for a
clean diagnostic main run. Dispatches on other branches allocate no runners.
Rewarm only when repeated cold PR runs justify it, such as after an image or
baseline update or cache eviction. Engineering owns measuring that tradeoff.

Keep ordinary read-only repository permissions and no credentials. GitHub caches
can be read by contributors/fork PRs; store only public-source compiler artifacts.
PR-scoped writes cannot populate main's cache. No privileged trigger, public
archive, custom cache server, cache-limit increase or billing change is introduced.
GitHub may evict unused entries or entries beyond the repository's cache limit.

## Alternatives and consequences

- Whole DerivedData/.build restoration can accidentally retain products, test
  reports and build databases and depends on source timestamps. Use native
  input-keyed compilation and SDK module caches instead.
- Automatic post-merge warming repeats the expensive full run just removed by
  ADR-0044. Optional main warming amortizes one run across subsequent PRs.
- PR-only caching needs no warm-up run but cannot accelerate the first run of
  another PR. Document this limit rather than promising universal warm builds.
- Removing builds, tests or analysis would reduce coverage; it is out of scope.
- Cache compression/upload/download costs time and storage. Measure cold and warm
  hosted runs on the same revision, including transfer overhead, before claiming
  a speedup. Old image caches naturally expire; do not increase the budget.

## Verification and limits

Execute all three local gates and record exact revision/results in the caching
PR. Verify action syntax and preserved workflow/command behavior. A local warm
probe must reuse only the allowed caches after discarding target build outputs.
Hosted acceptance requires full successful cold and warm runs, cache restore/save
and compiler hit evidence, plus all existing test counts. Future cross-PR reuse
requires the optional main warm-up after merge; PR runs cannot prove that scope.
No live-provider, other-Mac, release or billing-savings claim follows from CI.

References: [Apple build settings](https://developer.apple.com/documentation/xcode/build-settings-reference),
[GitHub cache behavior and scope](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching),
[actions/cache](https://github.com/actions/cache), [ADR-0044](0044-local-validation-ready-pr-ci.md),
[ADR-0045](0045-xcode-27-2-baseline.md).
