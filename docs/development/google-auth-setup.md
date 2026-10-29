# Developer accounts, keys, permissions and Google activation

Work package 08 implements the authentication code but deliberately ships with live
sign-in disabled. The maintainer confirmed on 2026-10-27 that no Apple developer or
Google OAuth setup exists yet. No account creation or enrollment is needed to review
this PR or run its synthetic tests. These are maintainer setup steps, not requirements
for future MacHandle users to create their own Cloud projects.

## Current personal-development plan — 2026-10-28

The maintainer is not preparing a release and has no legal organization or D-U-N-S number.
Start with free Apple developer registration using an existing personal Apple Account and
a dedicated Google development project in External Testing with an isolated test account.
A company, paid release enrollment, public submission or commissioned security audit is not
needed merely to keep developing or run the synthetic tests. Advanced signed capabilities
must still be checked against the account's actual provisioning support; free registration
is not proof that every signing/Keychain/login test is available.

[Apple's account comparison](https://developer.apple.com/help/account/basics/about-your-developer-account/)
distinguishes free development from paid capabilities. If paid membership becomes useful
for signed acceptance, individual enrollment is available without an organization/D-U-N-S
number. That identifier is an organization-enrollment requirement, not a prerequisite to
personal development. The production ownership decision can remain pending.

Apple compatibility has three separate evidence levels: local supported-API/sandbox testing,
Developer ID signing/notarization for direct distribution, and Mac App Store review if that
channel is later chosen. Notarization is not App Review approval. The existing sandbox and
public EventKit usage align with relevant [review requirements](https://developer.apple.com/app-store/review/guidelines/)
(2.4.5, 2.5.1), but this is a preliminary design observation, not approval or a complete
compliance audit. Signed privacy/permissions, helper packaging/MCP, experimental Notes and
future third-party data sharing remain specific gates. Only actual provider review can
establish a submission outcome. Do not assume an unfinished build would pass.

Creating a Google development project does not by itself require an external audit.
[Google's restricted-scope rules](https://developers.google.com/identity/protocols/oauth2/production-readiness/restricted-scope-verification)
distinguish verification and possible annual security assessment, including restricted
data stored on or transmitted through servers, with personal-use/development exceptions.
Sensitive and restricted are different categories. Check the exact requested scope's
classification in Google Auth Platform > Data Access, as described in the
[verification help](https://support.google.com/cloud/answer/13463073?hl=en).
This repository has not verified the maintainer's console classification or any exemption.
Do not commission an assessment merely to create the test project; reconsider before
production use or any scope/data-flow expansion. Future AI/server relaying must be assessed
on its actual data flow rather than assumed exempt because the app runs on a Mac.

MacHandle requests only `calendar.app.created`. The word "created" qualifies the secondary
calendars the app creates, not the permitted event operations: Google's
[scope definition](https://developers.google.com/workspace/calendar/api/auth) includes
reading, creating, editing and deleting events in those calendars. Editing a selected
Apple source event therefore updates its existing Google mirror using the saved ID;
no broad access to unrelated Google calendars is needed for that one-way design.
The update path is synthetically tested; live synchronization remains disabled pending
trusted setup and signed acceptance. Google edits are not synchronized back to Apple.

Work package 15 adds an explicit launch-at-login control. It grants no Calendar or Google
access and does not enable synchronization. Its actual signed registration, user approval,
logout/login and locked-session behavior still require authorized device tests.
The sections below retain detailed setup and historical work-package activation limits;
release steps are future preparation, not tasks the maintainer must complete now.

## What to create, and when

Start here even if you have never created a developer account. You can reuse an
existing personal Apple Account or Google Account that you control; developer setup
is separate from merely having those accounts. Official links below were checked on
2026-10-27. Console labels and requirements can change; no account-specific console
configuration or approval has been verified.

| Item | Purpose | When needed |
| --- | --- | --- |
| Apple Account with two-factor authentication | Own the developer identity and sign into Xcode | Before signed-device setup; no new account needed if you already have one |
| Apple developer registration / eventual Developer Program membership | Development identity, registered app identity and release signing | Free registration first; paid membership for intended Developer ID distribution, with release work in package 30 |
| Google Account controlling a Google Cloud project | Own Calendar API and OAuth configuration | Before live Google activation |
| Separate Google test account | Consent and revocation tests using disposable data | Before any live OAuth acceptance test |
| Desktop OAuth client ID | Identify MacHandle to Google | Before reviewed activation; this is public configuration, not a password |
| GitHub account and repository access | Review and develop the repository | Already in use; no additional account or token needed for this package |
| Public support contact, app website/privacy policy and domain ownership | Production branding and verification | Before public distribution/Google production approval as required |

Do the Apple and Google preparation below when ready, then return the limited handoff
information listed later. Creating accounts alone will not enable the current app's
Connect button: a reviewed activation change and signed tests are still required.

## Apple account and signing setup

1. Visit [Apple Account](https://account.apple.com/) and create an account only if
   needed. Enable two-factor authentication. Keep account recovery under your control.
2. Sign in at [Apple Developer](https://developer.apple.com/account/) and complete
   developer registration yourself. Add the account in Xcode Settings > Accounts.
   Free registration and paid membership are separate; see Apple's
   [developer account overview](https://developer.apple.com/help/account/basics/about-your-developer-account).
   Free registration is not proof that MacHandle's eventual signing and capabilities
   work; those need verification on the actual signed build.
3. Decide whether MacHandle will be owned/published by you personally or by a legal
   organization before enrolling. Apple's [enrollment page](https://developer.apple.com/programs/enroll/)
   explains individual versus organization requirements. Organization enrollment
   generally needs a legal entity, authority to bind it and a D-U-N-S number. Apple's
   listed membership price is USD 99/year as checked above, with regional variations.
   No purchase is needed merely to review this PR or run synthetic tests.
4. For the intended production identity, use the enrolled team's Certificates,
   Identifiers & Profiles to register the agreed explicit bundle ID. Do not register
   the proposal in ADR-0007 until ownership/name are decided. Select the intended team
   for local signing; keep personal team settings out of committed project files.
5. Release work will choose the appropriate signing certificate and notarization
   authentication. Do not generate an App Store Connect API key, upload signing
   private keys, or configure release credentials in CI for package 08. The existing
   CI intentionally has no release credentials.

There is no Apple Calendar developer API key to obtain for this implementation:
MacHandle uses EventKit on the Mac. Apple Account ownership/signing, macOS permission,
and MacHandle's own resource selection are separate. No Sign in with Apple, CloudKit
container, iCloud developer entitlement or app-specific Apple password is required by
this package. Existing account-backed calendars must already be available in Apple's
Calendar app for local discovery; MacHandle does not collect their login passwords.

## Apple identity and local credential ownership

1. Establish the maintainer's Apple developer identity and choose/register the final
   production bundle identifier under the intended team. Keep the existing development
   ID separate. The candidate in ADR-0007 is only a proposal, not an allocated identity.
2. Confirm the production credential service namespace and separate development/test
   namespaces. Keep personal signing-team settings and certificates out of Git. Use
   the [Apple developer account](https://developer.apple.com/account/) and
   [enrollment guidance](https://developer.apple.com/programs/enroll/) for current setup.
   Developer ID distribution and notarization remain package 30 work.
3. In an authorized signed test build, verify data-protection Keychain add/read/update/
   delete with synthetic secrets, locked-session failure, repeated builds/upgrades,
   separate installed copies and development/production isolation. Do not enable a
   sharing group or legacy-Keychain fallback to bypass a failure.

## Google project and consent

1. Create or choose the maintainer's [Google Account](https://accounts.google.com/).
   In [Google Cloud Console](https://console.cloud.google.com/), use the project
   selector to create a dedicated MacHandle development project. Keep future production
   configuration separate. A consumer Google Account can be the starting point;
   purchasing a Workspace domain is not a prerequisite for this desktop OAuth design.
2. With that project selected, open APIs & Services > Library, find **Google Calendar
   API**, and enable it. This package does not need Gmail, Drive or Contacts APIs.
3. Open Google Auth platform > Branding and complete Get Started: app name, support
   contact and developer contact. For personal-account testing choose **External**;
   Internal is for eligible Workspace organization use. Keep the external app in
   **Testing** and add only the isolated test account under Audience > Test users.
   Follow Google's [consent setup instructions](https://developers.google.com/workspace/guides/configure-oauth-consent).
4. In Data Access, add only `https://www.googleapis.com/auth/calendar.app.created`.
   It permits secondary calendar creation and managing events in those calendars,
   as described in Google's [scope catalog](https://developers.google.com/workspace/calendar/api/auth).
   Do not substitute full-calendar or all-events access. Record the console's scope
   classification and any verification requirements; this task has not verified them.
5. In Google Auth platform > Clients, create an OAuth client with application type
   **Desktop app** and a recognizable development name. Copy only the public client
   ID for the handoff. Follow Google's [credential instructions](https://developers.google.com/workspace/guides/create-credentials)
   and [desktop OAuth guidance](https://developers.google.com/identity/protocols/oauth2/native-app).
   MacHandle uses PKCE and a temporary localhost callback. Do not create a Web client,
   hosted redirect service, API key, service account or domain-wide delegation for it.
6. Do not embed a client secret or paste downloaded credential JSON into chat/Git.
   The implemented desktop flow uses no client secret. Future users simply sign in
   and consent in their browser; they do not need their own Cloud project/client ID.
7. Before public use, establish production branding, support/home/privacy URLs and
   domain verification as required by the console; review publishing and verification
   requirements with the final configuration. Testing status is not a permanent release
   plan. Test refresh invalidation explicitly. Client creation alone is not approval.

## Permissions on each Mac and in each account

| Permission | Where and when | MacHandle boundary |
| --- | --- | --- |
| Calendar access | Explicit Calendar enable action; macOS permission prompt, reviewable in System Settings > Privacy & Security > Calendars | macOS full access is broader than the app's selected read operations; choose sources inside MacHandle separately |
| Google Calendar OAuth consent | Browser after explicit Connect, once activation is implemented | Only app-created destination scope; no source transfer or synchronization exists in package 08 |
| Private Keychain storage | App-owned signed credential operations after activation | No separate account/key purchase; signed access, locked state and continuity still need testing |
| Sandbox networking | Reviewed app signing/entitlements during activation | Developer configuration, not a user privacy toggle; bounded loopback and outbound HTTPS require signed verification |
| Reminders and Contacts | Separate native opt-in and macOS prompts | Local read paths exist; real-account acceptance remains open. Do not pre-grant permissions for development tests. |
| MCP client access | Future local pairing and scoped approval | Planned; a Calendar or Google grant never authorizes an MCP client |
| Apple Notes | Experimental and unavailable after the [feasibility decision](../architecture/decisions/0031-notes-feasibility.md) | No account or permission enables Notes in this build. The isolated synthetic runtime gate remains deferred; do not grant Automation or use personal notes for testing. |
| Remote access | Future architecture gate | No supported activation instructions or account requirement established yet |

For the current Calendar design see [ADR-0011](../architecture/decisions/0011-calendar-authorization-discovery.md).
Use disposable calendars when later authorizing live tests. Do not grant Full Disk
Access, Accessibility or Automation as a workaround for unavailable features. Each
Mac needs its own verified local permissions and signing setup; Git handoff does not
copy consent or credentials. The private credential store is deliberately not synced.

No OpenAI API key or paid AI-provider account is required by the current MacHandle
implementation. A future MCP client's own service/subscription requirements will be
documented when that client is supported. Remote hosting, tunnels, certificates and
additional service accounts remain conditional on future design decisions; there is
nothing to provision for them in package 08.

## What to bring back, and what stays private

| Item | Handling |
| --- | --- |
| Chosen app ownership, agreed bundle ID, development/production distinction | Share the decision; public app identifiers can enter reviewed configuration |
| Google Desktop client ID and whether Calendar API/test audience/scope are configured | Public identifier and status are enough; share no downloaded credential file |
| Apple team/signing readiness | Report readiness; keep personal team settings out of Git even though a Team ID is an identifier rather than a secret |
| Passwords, MFA/recovery codes, OAuth authorization/access/refresh tokens | Never paste into chat, PRs, logs or Git; app token persistence belongs in private Keychain |
| Signing private keys, certificate exports, notarization/API credentials | Keep in controlled local storage; any future CI secret setup requires its own release review |
| Test-account email, billing details, account screenshots | Keep private; a simple setup-status report is sufficient |

A useful handoff is: “Apple registration ready; ownership decided; signing team ready
or pending; Google development project/API ready; External Testing configured; isolated
test user added; Desktop client ID ready; requested scope confirmed.” No passwords or
credentials are needed to plan the activation change. This guide does not create
accounts, accept terms, charge a card or grant live access on your behalf.

## Reviewed activation and isolated verification

After identities and test-client setup are ready, authorize an activation follow-up.
Wire a validated GoogleOAuthConfiguration into the composition root and choose the
correct credential namespace. Add justified sandbox network client/server entitlements
in that review; the server entitlement alone does not confine a listener to loopback.
The code explicitly binds 127.0.0.1, but signed sandbox behavior must be exercised.
Update overview/menu/Settings capability labels to reflect actual configured state
in that same activation review. Do not add end-user client-ID/secret entry fields or
silently enable an environment override.

Using only an explicitly authorized isolated test account, verify browser consent/refusal,
callback timeout/cancel, refresh, invalid-grant recovery, locked Keychain, disconnect
and separately confirmed project-wide revocation. Record local, signed-device and
Google results independently. Do not test revocation on a shared personal/project grant.
Disconnect removes local credentials; remote grant removal can affect other installations
and does not delete remote calendars. If programmatic revocation cannot be confirmed,
review the grant in Google Account security settings.

There is no event transfer or synchronization in package 08. Package 09 still needs
app-created destination ownership and privacy proof before source content can leave
the Mac. See [ADR-0013](../architecture/decisions/0013-google-oauth-keychain.md),
[ADR-0005](../architecture/decisions/0005-google-desktop-boundary.md) and
[ADR-0007](../architecture/decisions/0007-lifecycle-identity-and-distribution.md).

## Destination activation remains a separate gate

Work package 09 supplies an internal destination client, not working synchronization.
Do not wire it into the app when merely enabling OAuth. Its event/calendar identities
and uncertain-operation latches are memory-only. Activation needs durable identity/
recovery, one-writer enforcement, trusted consent and supported account-specific
calendar privacy verification. Event visibility=private and ownership markers do not
prove calendar sharing is private. See [ADR-0014](../architecture/decisions/0014-google-destination-client.md).

## Local database setup

Work package 10's SQLite library requires no new account, developer key, hosted database
or database server. The app does not open a store yet. Future activation uses private
local Application Support storage, with separate identities for development/production.
Do not copy a live database between Macs or put it in Git/cloud-sync folders; developer
handoff remains source-only. Restored metadata needs identity/remote verification and
future writer-transfer handling. See [ADR-0015](../architecture/decisions/0015-sqlite-persistence.md).

## Onboarding development build — work package 16

Connections now includes source choices, availability/detail preferences and reviewed sync
controls. Connect and sync remain disabled in the default build: adding a Desktop client
ID alone is insufficient. Your current personal development setup does not require an
organization/D-U-N-S number, a release submission or commissioning an audit. Follow the
account instructions above; public identifiers are enough for configuration discussion.
Never put tokens, private keys or client credentials into Git or a PR.

The [activation ledger](../implementation/prs/pr-16.md#open-activation-follow-up--not-a-completed-milestone)
assigns account identity, narrow-scope privacy proof, signed Keychain/runtime, trusted
source/lifecycle adapters and isolated live acceptance to the maintainer and engineering.
The scope's app-created restriction permits editing/deleting those calendars' events;
once enabled, Apple edits update the same Google copy. It does not mean create-only access.

When activation is verified: explicitly enable Calendar access, select Google sources,
connect Google, choose privacy, review the projected changes and confirm. Every deletion
set requires explicit approval. Review again after a pause or changed selection. Removing
a detail clears copied fields only after a successful confirmed sync. Disconnect stops
local work and retains remote events; grant revocation has a separate broader warning.
Restored preferences are paused candidates. Unknown writes show recovery attention and
must follow the [recovery procedure](sync-recovery.md), never blind replay or deletion.
