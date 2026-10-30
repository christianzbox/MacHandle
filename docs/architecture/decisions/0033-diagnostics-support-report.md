# ADR-0033: Allowlisted diagnostics and local support export

Date: 2026-10-29. Status: implemented for work package 29 review; no release certification.

## Context and evidence

[The audit](../../development/diagnostics-security-audit.md) found stale static claims in Diagnostics
and overly broad sample-history and retry wording. The current native composition offers opt-in
local reads, unconfigured Google sync and synthetic MCP/approval samples. It has no connected live
journal viewer, signed broker, remote service or Notes provider. Diagnostic navigation must not
probe permissions, credentials, providers or private stores merely to populate a dashboard.

## Decision

Use a closed `SupportReport` value in the existing MacHandleApplication module. Its input types are
fixed local opt-in/busy states, a sync phase, typed failure and busy flag. Capture synchronously
from observable UI state, without effects. Explicitly label opt-in as distinct from OS permission.
The report has a versioned fixed schema; exhaustive switches translate domain enums. It cannot
accept resource identities, selections, field grants, payloads, dates, arbitrary strings/errors,
paths, tokens, journal entries or databases. “Credentials not inspected” replaces an unsupported
claim that no credentials exist. Sample history and live provider audit are explicitly distinct.

Preview an immutable report before a user-initiated native plain-text file export. Only the Save
panel selects the destination; the app does not upload, auto-save, remember a destination or retain
security-scoped bookmarks. Add `com.apple.security.files.user-selected.read-write` for this action;
no broad home-folder, network, automation or provider entitlement is added. FileDocument is export
only. Display fixed success/cancellation/failure messages, never the destination URL or raw error.
A failed export can be retried because saving this metadata does not mutate provider data.

Diagnostics recovery controls navigate to existing trusted local screens. They do not retry a
mutation, clear uncertainty, reset a database or grant access. Generic sync failure wording now
requires status review and verification of uncertain writes. Existing paused/unknown/revoked rules
remain authoritative and unchanged.

## Alternatives and consequences

- Collecting logs and then redacting them would preserve more troubleshooting context but risks
  missing content or identifiers. Reject it; add any future fields through schema/privacy review.
- Hard-coded “all off/no credentials” text is simple but becomes false as local state changes.
  Read coarse model state and distinguish unavailable from unobserved.
- Clipboard-only export avoids a file entitlement but is less discoverable and replaces the user's
  clipboard. Choose explicit native preview/save with the narrow user-selected entitlement.
- Opening journals to create an audit dashboard would imply a live composition that does not exist.
  Defer that viewer until the signed/live integration, keeping internal records separate.

Coarse opt-in and sync states still disclose app usage; let the user inspect the exact report and
choose whether to share it. Save-panel locations may be cloud-backed, in which case that location's
provider handles the saved file. Never commit support exports or attach personal data to issues.
The entitlement permits user-selected file access; only signed sandbox testing can establish its
runtime enforcement. These unsigned checks do not establish that boundary.

## Validation and remaining gates

Synthetic tests check noninterference from private model data/raw failures, no provider calls during
capture, frozen snapshots, disabled precedence and bounded schema across phases/failures. Native
inspection covers default states, labels, scroll layout, report opening, save/cancel and navigation.
Repository gates and scoped resource evidence are recorded in [acceptance](../../implementation/prs/pr-29.md#implementation-and-acceptance).

Engineering owns live audit wiring, full accessibility/performance, signed save-panel and provider
end-to-end tests; maintainer supplies isolated setup and authorization. Revisit before advertising
those capabilities or releasing. Notes G1–G6 and remote R1–R6 remain deferred under ADRs 0031/0032.

References: Apple's [user-selected file entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.files.user-selected.read-write)
and [fileExporter](https://developer.apple.com/documentation/swiftui/view/fileexporter%28ispresented%3Adocument%3Acontenttype%3Adefaultfilename%3Aoncompletion%3A%29).
The pinned SDK compiles the API; native inspection is scoped unsigned evidence, not signing proof.
