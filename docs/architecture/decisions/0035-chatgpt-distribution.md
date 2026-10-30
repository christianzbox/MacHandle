# ADR-0035: Defer ChatGPT packaging until native authority is verified

Date: 2026-10-29. Status: work package 31 decision merged in GitHub PR #32; activation and distribution deferred.

## Context and evidence

Work package 30 merged in GitHub PR #31 at `5156700cdb8232720562207e10b1a1afa4807dc2`.
The current helper is synthetic stdio only. Signed broker/native pairing, real-client permission
enforcement, actual provider writes and release acceptance remain unverified. The maintainer has
not established production signing/account setup and does not intend public release yet.

The dated [platform matrix](../../development/chatgpt-distribution.md) separates private desktop,
workspace, private remote and public routes, account eligibility, native versus client approval,
and foreground versus scheduled use. Official documentation establishes possibilities, not proof
that MacHandle or this account can use them. Existing remote R1–R6 and release P1–P5 still apply.

## Decision

Complete the numbered package through an explicit owned deferral. Do not ship an installable
manifest, marketplace entry or ZIP that appears to connect MacHandle while launching only a fixture
helper. Add clear native ChatGPT availability wording, a future setup/acceptance protocol and a
navigation index of remaining activation gates. No provider, entitlement, credential, listener,
package runtime or trusted policy behavior changes.

Prefer a private desktop client experiment after signed local pairing and selected-read proof.
This is a sequencing recommendation, not authorization or proof of client compatibility. Retain
the private authenticated tunnel candidate in ADR-0032 for a later remote requirement. Neither
route changes the requirement for trusted local authorization or creates a cloud dependency for
local use. Keep write and scheduled-task acceptance separate from discovery/read acceptance.

## Alternatives and consequences

- A synthetic demo plugin could prove installation but not the native integration the user needs.
  Defer it to a specifically authorized compatibility experiment rather than distribute misleading
  metadata now. Existing subprocess/SDK tests already cover the fixture transport.
- Private desktop testing minimizes new infrastructure, but depends on verified native identity,
  installed client eligibility and a running Mac. It does not prove web/mobile or scheduled support.
- Private remote testing can support a web client, but adds identity, authenticated transport,
  reachability, isolation and offline behavior. Preserve R1–R6 instead of weakening authentication.
- Public desktop or hosted distribution needs separate eligibility and review evidence as well as
  a supported signed product. Packaging alone cannot satisfy either platform or Apple acceptance.
- A UI component or skill is optional packaging, not a replacement for native policy. None is added
  without a supported use case. No legacy HTTP plugin manifest is invented.

## Verification and retained requirements

The original PR-31 and specification §8.6/8.7 remain intact. The matrix covers every requested
distribution topic; client cases and recurring availability protocol are explicitly unexecuted.
Repository validation covers existing synthetic behavior and compiled native presentation only.
Engineering owns implementation and evidence; the maintainer owns identity/setup and submission
decisions. Revisit on signed local bridge/read proof plus confirmed client eligibility, or material
platform changes. Remote and public activation retain their existing R/P prerequisites.

The [activation backlog](../../implementation/activation-backlog.md) links authoritative gate owners
without declaring milestones complete or assigning speculative PR counts. After this PR, stop for
review; selecting a follow-up requires a new bounded authorization.
