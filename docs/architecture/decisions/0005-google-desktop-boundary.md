# ADR-0005: Google desktop authorization and destination boundary

Date: 2026-10-23 (America/Detroit). Status: accepted design for PR-02 review;
official-source research, no OAuth client, account or API call exercised.
Requirements: master specification §§4, 7 and 13.

## Decision

Use a maintainer-managed **Desktop app** OAuth client, external system browser,
authorization code, PKCE S256 and per-attempt unpredictable state. Use a short-lived
loopback IP redirect with an OS-assigned port. Google documents desktop loopback
support in its [migration guide](https://developers.google.com/identity/protocols/oauth2/resources/loopback-migration)
and [desktop flow](https://developers.google.com/identity/protocols/oauth2/native-app)
(rechecked today). Desktop clients are public; a client ID or distributed client
secret cannot authenticate a trusted installation. No confidential server credential
belongs in the app. Token exchange/refresh is HTTPS; persistent tokens go to Keychain.

The callback is only an OAuth response receiver, never an MCP/data endpoint. PR-08
must bind literal loopback only (not wildcard or a hostname), bind before opening
the browser, validate the exact path/redirect and state, accept one matching response,
and tear down on success, cancellation or timeout. Reject malformed/duplicate
parameters and replay. Keep authorization codes, verifier, state, URLs and tokens
out of logs. PKCE does not replace local connection policy or approval.
These are MacHandle design requirements consistent with
[RFC 8252 §§7.3, 8](https://datatracker.ietf.org/doc/html/rfc8252).

A sandboxed callback will require incoming-network capability and token/API requests
outgoing-network capability in PR-08, with a signed loopback test before acceptance.
Apple's [server entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.network.server)
controls connection initiation; it does not restrict a listener to loopback or
provide authentication. Add no network capability in PR-02.

## Narrow scope operation audit

Select only `https://www.googleapis.com/auth/calendar.app.created` for calendar
mirroring. The [scope catalog](https://developers.google.com/workspace/calendar/api/auth)
describes secondary-calendar creation and events on those calendars. It is not a
grant to unrelated calendars, nor proof of MacHandle's selected destination ownership.
The following method authorization tables were individually checked on 2026-10-23:

| Method | Lists app-created scope? | Consequence |
| --- | --- | --- |
| [calendars.insert](https://developers.google.com/workspace/calendar/api/v3/reference/calendars/insert) | Yes | Create a secondary destination as the consenting user; persist the returned ID, never use `primary`. |
| [calendars.get](https://developers.google.com/workspace/calendar/api/v3/reference/calendars/get) | Yes | Recheck metadata of the recorded destination. This does not prove ACL privacy. |
| [events.list](https://developers.google.com/workspace/calendar/api/v3/reference/events/list) | Yes | Read destination with pagination; incomplete pages never authorize deletion. |
| [events.get](https://developers.google.com/workspace/calendar/api/v3/reference/events/get) | Yes | Verify an identified destination event. |
| [events.insert](https://developers.google.com/workspace/calendar/api/v3/reference/events/insert) | Yes | Create only in the recorded destination. |
| [events.update](https://developers.google.com/workspace/calendar/api/v3/reference/events/update) | Yes | Update owned mirrored events; preserve conflict/precondition checks. |
| [events.delete](https://developers.google.com/workspace/calendar/api/v3/reference/events/delete) | Yes | Guarded deletion of owned events only. |
| [calendars.delete](https://developers.google.com/workspace/calendar/api/v3/reference/calendars/delete) | Yes | Possible explicit destination cleanup; never an automatic disconnect side effect. |
| [calendarList.list](https://developers.google.com/workspace/calendar/api/v3/reference/calendarList/list) | No | Do not rely on account-wide enumeration to rediscover a lost destination. |
| [acl.list](https://developers.google.com/workspace/calendar/api/v3/reference/acl/list) | No | Cannot attest continued privacy or inspect organization sharing policy with this scope alone. |

This is a documented scope fit, not live proof that a particular account/client can
perform the sequence. PR-09 must exercise create/get/list/insert/update/delete with
only this scope in an explicitly authorized synthetic account, prove rejection of
unrelated targets and inspect actual privacy before transmitting source content.
Do not assume a calendar title establishes identity. Store an opaque destination
reference, installation/mapping ownership and observed remote version separately.
Never send attendee lists, invitations, sharing changes or provider IDs as user-visible
content. Detailed mode remains explicit opt-in; privacy reduction removes details.

## Remote mutation preconditions

The [resource-version guide](https://developers.google.com/workspace/calendar/api/guides/version-resources)
(rechecked 2026-10-23) supports conditional updates/deletes using the previously
observed ETag in `If-Match`; a changed resource returns HTTP 412. This is the remote
precondition mechanism PR-09/12 must test, not just a local read-before-write check.
On 412, refetch and replan under current policy/approval; never retry unconditionally.
Keep opaque version evidence in domain contracts without importing HTTP semantics.

[events.update](https://developers.google.com/workspace/calendar/api/v3/reference/events/update)
replaces the resource rather than patching a few fields. PR-09/12 must deliberately
construct the authorized desired representation, including removal of formerly
shared details when privacy tightens. Do not round-trip unexpected remote fields
or overwrite a user-edited version without the conflict policy.

Inserts have no conditional-modification guarantee. A caller-supplied event ID can
support recovery from an uncertain create result, as described in Google's
[event-creation guide](https://developers.google.com/workspace/calendar/api/guides/create-events).
PR-09/12 must persist an opaque destination event ID/operation identity before dispatch,
then verify identity/ownership/content after a timeout or duplicate-ID response.
Never generate a fresh ID on each retry or treat a collision as proof of success.
These are researched API constraints; real failure-injection evidence remains later.

## Privacy and recovery gate

The private-secondary-calendar requirement remains unchanged. Workspace policy and
later user sharing can affect actual visibility. The narrow scope cannot continuously
verify ACLs. PR-09/16 must establish a supported, reviewable privacy verification flow
for the supported account types **before any source-content transfer**, or block
activation for cases that cannot satisfy the requirement. Do not silently broaden
scope, treat event `visibility` as calendar privacy, or claim permanent privacy.
Any proposal to add ACL-read scope needs a deliberate requirement/consent review.

Loss of the saved destination ID cannot be repaired by `calendarList.list` with the
chosen scope. PR-10/14 must design durable destination recovery/ownership transfer
and explicit user-assisted recovery when identity cannot be proven. Suspend writes;
do not select a calendar by name, silently create duplicate mirrors, or infer deletion
from unavailable state. The single active writer across Macs remains a separate gate.

## Production consent and token constraints

Google's [verification guidance](https://developers.google.com/identity/protocols/oauth2/production-readiness/sensitive-scope-verification)
places final scope classification in the project's Data Access console. The public
Calendar catalog does not label this scope's sensitivity. **Classification and actual
verification approval remain unverified**, owned by the maintainer in PR-08/16;
no assertion of non-sensitive status or exemption. Check the exact scope and consent
configuration, administrator restrictions, required demonstration and policy compliance.

[Brand verification](https://developers.google.com/identity/protocols/oauth2/production-readiness/brand-verification)
is separate: arrange the application home page, privacy policy, verified domain and
support identity before public onboarding. Use distinct development/production
projects and no user-created Cloud-project prerequisite in the published product.
No console, account or credentials were accessed in this PR.

The [OAuth lifecycle guide](https://developers.google.com/identity/protocols/oauth2/)
documents seven-day refresh-token expiry for external Testing projects requesting
more than basic identity scopes, as well as other invalidation/limit cases. PR-08 must
handle refusal, scope mismatch, refresh failure, rotation and revoked access without
blind retries; disconnect disables local work immediately and handles remote revocation
separately. A revocation failure must not restore local access. Public sync cannot
rely indefinitely on Testing status.

Google's [token-revocation section](https://developers.google.com/identity/protocols/oauth2/native-app#tokenrevoke)
(rechecked 2026-10-23) says revocation removes the user's grant across scopes and
clients in the same project, and full effect can be delayed. **It is not a per-Mac
or per-MacHandle-connection revoke primitive.** PR-08/14/16 must distinguish stopping
this Mac locally from revoking the Google grant, disclose possible impact on other
installations for that account/project, and test reauthorization/standby recovery.
A local pause or writer handoff must not silently invoke project-grant revocation.
Explicit disconnect/revoke still disables local work immediately; remote completion
and remote-data deletion are separate outcomes. No claim of instantaneous global
revocation or device-scoped remote isolation is justified. This reinforces separate
development/production projects and does not connect Google authorization to MCP.

[Calendar quotas](https://developers.google.com/workspace/calendar/api/guides/quota)
include project/user and operational constraints. PR-09/12 owns bounded jittered
backoff, pagination and failure recovery; production quota/billing configuration must
be rechecked before release rather than baking a research-time number into policy.

## Alternatives and consequences

Custom-scheme redirects avoid a local socket but introduce handler ownership and
client-type compatibility questions. The current desktop guide is internally
inconsistent: its parameter table still includes custom-scheme examples, while its
later redirect section says custom schemes are no longer supported. Do not treat
those examples as proof of an available fallback. Choose the explicitly documented
desktop loopback route; PR-08 may revisit alternatives only with unambiguous current
provider support and redirect/security evidence. Embedded web views,
out-of-band copy/paste codes and a custom hosted OAuth proxy are not the baseline.
A proxy would introduce a new trust/operations boundary without a demonstrated need.

Broad Calendar access makes discovery and ACL inspection easier but violates least
privilege for the current mirroring design. Keep narrow scope and expose the privacy
and recovery gates rather than granting unrelated-calendar access preemptively.
An OAuth library may reduce implementation risk; PR-08 evaluates maintained native
options against a small URLSession adapter and records the dependency decision.
No SDK dependency or full OAuth prototype is retained here.

## Work package 08 implementation update

[ADR-0013](0013-google-oauth-keychain.md) implements injectable browser PKCE/loopback,
token lifecycle and the private data-protection Keychain adapter. The maintainer has
no developer/OAuth setup yet; the app deliberately remains unconfigured. No network
entitlements, production identity or credential is added. Signed Keychain, sandbox,
Google consent/refresh/revocation and production approval gates remain open. See the
[activation checklist](../../development/google-auth-setup.md) for owner/trigger and setup.
