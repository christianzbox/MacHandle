# ADR-0013 — Google authentication and private credentials

Date: 2026-10-27. Status: work package 08 merged in GitHub PR #9 at
`4d80fabae8b2b3a4482b582a48e974656a02eb3f`; live activation remains blocked on
maintainer setup and signed verification. Not released.
Predecessor GitHub PR #8 merged at `34c5c55019d805514117cb41c99adc5c67b1ba9a`
on 2026-10-26 20:34:06 UTC. Requirements: specification PR-08 and §§7.3–7.4, 13, 20.

## Context and current evidence

The maintainer confirmed on 2026-10-27 that no Apple developer or Google OAuth setup
exists yet. Work package 08's brief permits completing injectable implementation
while keeping live activation blocked. No client ID, production bundle identity,
signing team, Google project or credential was invented. The shipping composition
creates an unconfigured GoogleConnectionModel; no service, socket, browser request,
Keychain access or Google request starts. Calendar/MCP previews remain independent.

Official sources rechecked on 2026-10-27:

- Google's [desktop flow](https://developers.google.com/identity/protocols/oauth2/native-app)
  specifies browser authorization, PKCE, token exchange/refresh and revocation. Client
  secret is optional for this public-client flow. Revocation affects the user's
  project-wide grant and may propagate asynchronously. We use no client secret.
- The [loopback migration guide](https://developers.google.com/identity/protocols/oauth2/resources/loopback-migration)
  retains Desktop app loopback support. The [Calendar scope catalog](https://developers.google.com/workspace/calendar/api/auth)
  describes app-created calendars/events; it does not establish console classification
  or production verification approval.
- Google's [OAuth lifecycle](https://developers.google.com/identity/protocols/oauth2)
  documents refresh invalidation and the Testing-project lifetime constraint. No
  refresh lifetime is promised; invalid grants require explicit reauthentication.
- Apple's [data-protection Keychain](https://developer.apple.com/documentation/security/ksecusedataprotectionkeychain)
  documentation was read via its Markdown version. The pinned SDK rejects deprecated
  authentication-UI suppression; use a fresh LAContext with interactionNotAllowed.
  This API evidence is separate from actual signed Keychain behavior.

## Decision and trust boundary

Create one cohesive GoogleAuthorization module, independent of CoreDomain,
PermissionEngine, EventKit and MCP. It owns protocol validation, live adapters,
authentication lifecycle and a display-only observable model. Inject internal
browser/HTTP/credential/clock dependencies for synthetic tests. Public views receive
status/actions, never tokens, credentials, transport objects or raw Google errors.
No token-returning public API exists yet; package 09 must introduce only the narrow
trusted destination-client boundary it needs.

GoogleOAuthConfiguration accepts a reviewed client ID and credential namespace; it
cannot override endpoints or scopes. The only scope is calendar.app.created. Explicit
Connect may resume a saved valid credential or start the browser flow. Startup remains
disconnected and does not read Keychain or refresh. Authorization does not select Apple
calendars, grant local writes, enable sync or authenticate an MCP client.

Each browser attempt generates independent 256-bit random state and verifier using
SecRandomCopyBytes, and derives S256 with CryptoKit. The callback binds literal
127.0.0.1 on an OS-assigned port before opening NSWorkspace's external browser.
Only /oauth/callback is accepted, with exact Host/redirect/state, GET/HTTP1.1,
no fragment/userinfo, no duplicate query parameters or ambiguous code/error response.
No resource payload is served. Wrong state/path/headers return a generic 400 and do
not complete authorization. A matching refusal is a sanitized result. One accepted
response closes the listener; completion/cancel/timeout close pending connections.

Limits are 180 seconds per attempt, 5 seconds per accepted connection, 8 simultaneous
connections, 32 connections per attempt and 8 KiB input per connection. Unexpected
local traffic can exhaust the attempt; retry requires user action. These bounds limit
resource use, not denial-of-service resistance. State/PKCE are not authority for
Calendar reads or approval. Plain localhost HTTP is confined to the callback; Google
requests use fixed HTTPS endpoints and normal platform certificate verification.

Token exchange/refresh/revoke use form POST bodies, ephemeral URLSession without
cookies or disk cache, no redirects, 30/45-second request/resource timeouts and a
64 KiB response limit. Only Bearer, nonempty bounded tokens and 60-second-to-one-day
access lifetimes are accepted; unexpected provider behavior fails closed. Initial
scope must exactly match the requested scope; a refresh may omit scope and retain
its validated prior grant. Refresh-token rotation is saved; absent refresh rotation
retains the prior token. Unknown provider errors are sanitized, never echoed/logged.
DPoP is optional in current Google documentation and is not implemented here; revisit
in authentication hardening if required by provider policy or threat-model changes.

## Credential lifecycle and concurrency

GoogleAuthentication serializes writes/deletes to its private store. Actor generations
fence every asynchronous completion. Disconnect stops local use before awaiting remote
revocation; late sign-in/refresh results cannot recreate credentials. Concurrent refresh
checks share one task, and the owner persists once. Cancel Sign-in cancels the attempt;
network cancellation is best-effort, with stale results discarded. Already accepted
Google operations cannot be undone by cancelling a Swift task.

Credentials are versioned, client-bound records in a single private generic-password
Keychain item. Every query opts into data protection, disables synchronization, uses
an explicit service/account and suppresses interaction with LAContext. New/updated
items use WhenUnlockedThisDeviceOnly. No access group, shared helper, legacy fallback,
plaintext preference/export or credential migration is introduced. Locked/unavailable
Keychain pauses use and makes deletion failure visible. Malformed/wrong-client records
require explicit disconnect, not silent overwrite. Invalid grants delete the local
credential; transient failures stop access while retaining it for an explicit retry.

Disconnect This Mac deletes only the local item. Revoke Google Grant requires a separate
confirmation explaining effects on other installations. Local deletion precedes remote
revocation, and a remote failure cannot restore access. If the token is already missing
or could not be read, remote revocation cannot be claimed; Google Account controls are
the recovery route. No operation deletes calendars/events. Swift/OS internals may retain
in-flight copies until requests finish; no memory-zeroization guarantee is made.

## Alternatives and consequences

A third-party OAuth SDK could reduce protocol maintenance, but adds dependency and
callback-policy review. This bounded native implementation uses platform crypto/network
APIs, keeps dependencies explicit, and requires retained adversarial callback tests.
No home-grown crypto primitive is used. Embedded web views and copy/paste codes are
rejected; documented Desktop loopback support is the chosen redirect route.

Putting auth in CoreDomain or sharing preview policy would couple transport/secrets to
resource rules. A dedicated target and private credential API preserve that separation.
Automatically resuming credentials on launch would be convenient but weakens explicit
opt-in. This package requires Connect each session; later background work needs a
separate consent/lifecycle decision. Retaining only refresh tokens was considered;
keeping access/refresh/expiry together permits bounded validity checks without extra
network traffic, while all persisted token material remains in Keychain.

Production setup is unavailable. Adding network entitlements or a guessed client ID
would not establish signed acceptance, so the application remains unconfigured with
unchanged Calendar-only sandbox capabilities. The live adapters compile and the
unsandboxed local receiver is tested. Activation requires a reviewed composition change,
network client/server entitlements, confirmed identities and the checklist below.
This is a documented activation deferral, not a claim of working Google sign-in.

## Verification and remaining gates

Synthetic tests cover RFC PKCE, callback/state/redirect/HTTP validation, narrow scopes,
form encoding, token rotation, invalid grants, unavailable storage, cancellation,
late-result fences, disconnect/revocation failure, private UI and compiler boundaries.
A real local Network listener is exercised with synthetic HTTP callbacks, cancellation
and timeout. No Google account or actual Keychain item is accessed. Native UI inspection
and exact standard/local/hosted evidence are recorded in the review PR and progress.

Owner: maintainer plus authentication work. Revisit live activation after Apple identity,
Google Desktop client/consent setup and isolated test-account authorization exist. Verify
signed Keychain read/write/delete, locked state, upgrade/separate-copy/channel isolation,
sandbox loopback, browser consent, refusal, refresh, revocation and reauthentication
before claiming live authentication. Production consent classification/verification,
brand/domain support, Testing versus Production policy and release identity remain
unverified. The [account, permissions and activation guide](../../development/google-auth-setup.md) gives the
handoff. Package 09 may build synthetic client contracts but cannot transfer Calendar
content until authentication and destination privacy gates pass. Prior Calendar live
acceptance, home-Mac, Intel/minimum-OS and distribution gates remain open.

## Work package 09 boundary refinement

[ADR-0014](0014-google-destination-client.md) adds an internal authenticated Calendar
transport without exporting tokens. Session leases and tracked requests extend
revocation fences to API dispatch/completion. Shared refresh persists before waiters
send. The destination client remains inaccessible to views and is not composed into
the app; all previous signed/console/credential gates remain open.

## Work package 16 follow-up

[ADR-0021](0021-google-sync-onboarding.md) adds native local onboarding, retained reviews,
serialized composition and schema-v3 candidate preferences. Existing authority/recovery
checks remain independent. Signed/live composition, private-sharing proof and actual
account acceptance remain an owned activation follow-up; they are not satisfied by the
new UI or transferred to MCP. The default app remains unconfigured.
