# Maintainer account and release checklist

Checked 2026-10-29. The maintainer currently has no established developer account/signing setup and
is **not preparing a public release**. Synthetic development and local packaging require none of the
accounts below. This is a preparation checklist, not an instruction to purchase, enroll or submit now.

## Apple: development first, distribution later

1. When ready for device development, use an Apple Account with two-factor authentication and register
   for free on [Apple's developer site](https://developer.apple.com/register/). The maintainer must
   review/accept agreements. Xcode/local synthetic builds can continue without enrolling in a paid
   program; free registration does not establish support for every signed capability test.
2. When Developer ID testing/distribution becomes useful, choose the ownership model before enrolling.
   [Individual enrollment](https://developer.apple.com/programs/enroll/) is available without a company;
   use your legal identity. Apple says an individual does **not** need a
   [D-U-N-S number](https://developer.apple.com/help/account/membership/D-U-N-S).
   Organization enrollment requires an eligible legal entity, D-U-N-S (with Apple's stated exceptions),
   binding authority and other enrollment evidence. Do not create a company merely to run these tests.
   Apple lists a paid annual membership on its [program page](https://developer.apple.com/programs/);
   recheck local pricing/terms when deciding to enroll.
3. Decide and register/confirm a stable production bundle identifier under the chosen team. Keep
   `org.machandle.development` for current development. Do not treat an example reverse-DNS identifier
   as an owned registration. Public team/bundle identifiers may be discussed; private keys must stay
   on the signing Mac in Keychain or an explicitly approved secret store.
4. Later obtain a [Developer ID Application certificate](https://developer.apple.com/help/account/certificates/create-developer-id-certificates/)
   for direct Mac app distribution. A Developer ID Installer certificate is for installer packages,
   not a requirement for this local ZIP rehearsal. Apple documents Account Holder/cloud-managed roles;
   use the actual account's permitted workflow. Never export/upload a signing private key to a PR.
5. Configure notarization credentials locally only when the signed track is authorized. No credentials
   belong in ordinary PR CI. Keep account recovery and certificate custody documented privately.
   Follow [P1–P5](release-engineering.md#owned-release-gates) before any distribution.

Developer ID/notarization and Mac App Store review are separate paths. Apple's
[notary service](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
is not App Review and does not certify all MacHandle behavior. No Apple approval is claimed; public
API use and passing tests alone cannot predict an App Store decision.

## Google: isolated testing only when needed

Follow the existing [Google setup guide](google-auth-setup.md) for a dedicated development project,
Calendar API, External Testing consent, an isolated test user and a Desktop OAuth client. Keep the
production OAuth project/identity separate. Current activation remains disabled even after a client
ID exists: signed Keychain/runtime, private destination proof and provider integration are additional
gates. Public client identifiers are sufficient for setup discussion; never send tokens, client
credentials or private account data to a chat/PR. Do not broaden the calendar scope to bypass a gate.

The Google guide owns scope classification, verification/security-assessment questions and official
sources. Check the actual console and data flow before production or any server/AI relay; creating a
test project is not evidence that an audit is required, nor proof of an exemption. No Google project,
OAuth consent, permission or credential is created by the packaging tools.

## Other services and permission prompts

- GitHub already hosts source/CI. No extra GitHub release token or elevated Actions permission is
  needed for local rehearsal. Future publication requires maintainer approval and P5.
- SQLite is local software: no hosted database account or key is needed.
- Apple Calendar, Reminders and Contacts permissions are independent, explicit local opt-ins. Keep
  the personal iCloud profile out of testing; use a separate user/test account with synthetic data
  only after live testing is authorized. Packaging never launches the app or requests these grants.
- Notes, remote tunnel/identity hosting and ChatGPT/plugin distribution are deferred. Do not buy a
  domain, host a service or configure a personal client just to complete this package. Revisit the
  [remote matrix](remote-mcp.md) and [ChatGPT decision](chatgpt-distribution.md) before any separately authorized setup.

Share only the public identity decisions and which setup steps are complete. Keep passwords, signing
keys, credential exports, access/refresh tokens, certificate profiles and personal records private.

## ChatGPT preparation after the distribution decision

The [dated compatibility/setup matrix](chatgpt-distribution.md) owns private desktop, workspace,
private remote and public plugin prerequisites. No API key is needed for this documentation or
synthetic development. Confirm actual client/plan/workspace availability before choosing an account
or infrastructure path. The native bridge must be verified before packaging can expose Apple data.
Public publishing identity and desktop-partner eligibility are separate later gates, not reasons
to enroll or submit now. No account creation is required to review this package.
