# ADR-0007: Lifecycle, stable identity and distribution

Date: 2026-10-23 (America/Detroit). Status: accepted strategy for PR-02 review;
production identity allocation, signed Keychain continuity and release remain gates.
Requirements: master specification §§7.9–7.10, 12.5, 13 and 21–22.

## Background strategy

Use a user-session menu bar app with optional launch at login through
[`SMAppService.mainApp`](https://developer.apple.com/documentation/servicemanagement/smappservice),
available from macOS 13 (official documentation checked today and macOS 14 typecheck).
The main app owns the scheduling coordinator initially. Closing a window and quitting
the app must have distinct, visible behavior in PR-05/15. Registration is explicit
opt-in; respect disabled/approval-required service state rather than silently
re-registering. Do not install a root daemon or start work before consent.

PR-15 combines EventKit change notifications with debouncing, bounded periodic
reconciliation and wake/network recovery. Notifications invalidate snapshots; they
are not a complete event log or evidence of remote freshness. Use one serialized
local job, cancellation and bounded retry with jitter; restart from durable state.
Mac sleep, logout, quit and power-off suspend progress. Launch at login is not a
scheduling SLA or permission to keep the machine awake. App Nap/energy behavior
and actual wake scheduling require measurement; no timers or launch agents added now.

Alternatives: a dedicated per-user service can outlive the UI but creates another
lifecycle and authorization owner; revisit in PR-15/17 only if the measured app-only
strategy cannot meet requirements. Root/global daemons and busy polling add privilege
or energy cost without a present need. Local serialization does not solve two-Mac
ownership; PR-14 must implement safe single-writer transfer independently.

## Bundle and Keychain identity

Keep the current `org.machandle.development` build ID for this documentation PR.
Do not store production credentials under it. Adopt a stable reverse-DNS production
namespace owned by the maintainer before PR-08 persists credentials. Candidate:
`io.github.christianzbox.MacHandle`, derived from the public repository namespace;
this is a proposal, **not evidence of Apple registration or signing-team ownership**.
The maintainer must confirm/register the final ID and signing team before PR-08;
PR-30 verifies distribution continuity. Keep development/test and production IDs,
OAuth projects, Keychain services and data containers separate. PR-06 also needs a
stable development identity for meaningful repeatable TCC tests.

Plan one credential owner in the app-side broker, private Keychain items and no
helper-wide sharing group by default. Select the data-protection Keychain explicitly
for the future credential store, with a stable service/account namespace, non-synced
items, and an explicit accessibility policy. Begin with unlocked-device access;
if the Keychain is unavailable while locked, pause/retry instead of exporting secrets
or weakening access silently. PR-08/15 must verify this choice against background
requirements on actual macOS builds before accepting locked-session behavior.

Apple's [Keychain access-group guide](https://developer.apple.com/documentation/security/sharing-access-to-keychain-items-among-a-collection-of-apps)
explains that macOS data-protection Keychain groups depend on signing entitlements
and team/application identifiers. Merely keeping a bundle string does not prove
credential continuity. Its [accessibility guide](https://developer.apple.com/documentation/security/restricting-keychain-item-accessibility)
describes lock-state and device-only choices; verify their macOS implementation in
PR-08 rather than assuming every iOS behavior applies. No credential operation was
performed here, and no group/team entitlement is added.

[Code-signing requirements](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements)
and [sandbox-container identity](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox)
can differ across development and distribution channels. Use observed signed
requirements to define trusted peers, not a guessed team or bundle label. PR-08/30
must test same-channel upgrades, renewal, uninstall/reinstall, a second installed
copy and development/distribution separation using synthetic secrets. Team/ID/channel
changes need an explicit migration or reauthorization path; never promise transparent
migration before proving it. Product credentials do not travel via this Git handoff.

## Signing and notarization strategy

Target direct Developer ID distribution, as required by the canonical plan. Keep
App Sandbox and hardened runtime; keep ordinary PR builds unsigned/ad-hoc and free
of release credentials. This separates reproducible compile validation from shipping
trust. App Store distribution would add review and packaging constraints and is not
required for the initial release; sandboxing remains useful outside the store.

Apple's [notarization requirements](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
(rechecked 2026-10-23) require appropriate Developer ID signing, secure timestamps,
hardened runtime and valid nested executable signatures; no distribution
`get-task-allow`. Plan signing inside-out, then `notarytool` submission, inspect the
result/log, staple and validate the ticket. PR-30 must test the downloaded/quarantined
artifact through Gatekeeper on clean minimum/current OS systems, including offline
staple behavior and embedded helper launches. Do not use `codesign --deep` as a
substitute for deliberately signing nested targets or tell users to bypass Gatekeeper.

Notarization is Apple's automated check, not App Review or a proof of the app's
privacy model. A successful unsigned CI build proves none of Developer ID identity,
Keychain continuity, runtime entitlements, Gatekeeper acceptance or public readiness.
Release jobs/credentials need explicit later authorization and protected separation
from untrusted PR execution; no publishing workflow or credential is introduced now.

## Open gates and consequences

| Decision or evidence still required | Owner / revisit trigger |
| --- | --- |
| Final production bundle ID and signing-team registration; credential namespace | Maintainer with PR-08, before persistent production secrets; record public identifier decision without personal team settings or credentials. |
| Data-protection Keychain accessibility, upgrade continuity, locked-session behavior | PR-08/15, synthetic secrets under intended signed identities; block unsupported background access. |
| Login opt-in/status, window/quit behavior, sleep/wake/offline retry and energy measurements | PR-05/15, authorized synthetic lifecycle tests. |
| Per-user helper packaging, service registration and peer requirements if needed | PR-17 under ADR-0006; no speculative helper installation now. |
| Developer ID/notary access, signed minimum-OS/Intel matrix, privacy tests, release/update policy | Maintainer and PR-29/30 before a separately authorized publication. |

These gates do not block pure domain models in PR-03. They do block claiming working
background integration, credential continuity or distributable software today.

## Work package 05 implementation boundary

[ADR-0010](0010-native-application-foundation.md) implements the native window/menu
composition and in-memory preview lifecycle. Closing the window retains the process;
Quit exits. No background synchronization or login registration exists. Package 15
retains opt-in scheduling/login ownership; production identity and signing gates above
remain unresolved. Runtime evidence and the status-item inspection limit are in ADR-0010.

## Work package 08 implementation update

[ADR-0013](0013-google-oauth-keychain.md) implements injectable browser PKCE/loopback,
token lifecycle and the private data-protection Keychain adapter. The maintainer has
no developer/OAuth setup yet; the app deliberately remains unconfigured. No network
entitlements, production identity or credential is added. Signed Keychain, sandbox,
Google consent/refresh/revocation and production approval gates remain open. See the
[activation checklist](../../development/google-auth-setup.md) for owner/trigger and setup.

## Work package 15 follow-up — 2026-10-28

[ADR-0020](0020-background-synchronization.md) implements the internal monotonic coordinator,
serialized drain/cancellation, bounded preparation retries and native lifecycle adapters.
Settings now has explicit launch-at-login control; it never enables synchronization.
Pause/drain precedes writer transfer, and durable journal recovery remains mandatory.
Synthetic lifecycle and idle harness evidence are separate from signed login, locked
Keychain, physical sleep/network and two-Mac acceptance. Trusted live composition remains
package 16, not an automatic consequence of enabling login.
