# Google authentication activation checklist

Work package 08 implements the authentication code but deliberately ships with live
sign-in disabled. The maintainer confirmed on 2026-10-27 that no Apple developer or
Google OAuth setup exists yet. No account creation or enrollment is needed to review
this PR or run its synthetic tests. These are maintainer setup steps, not requirements
for future MacHandle users to create their own Cloud projects.

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

1. Establish a maintainer-owned Google Cloud project and separate test/production
   configuration. Enable the Calendar API for that project.
2. Configure branding, audience/test users and Data Access. Request only
   `https://www.googleapis.com/auth/calendar.app.created`. Check its classification in
   the console and complete any required verification; classification/approval has not
   been verified in this task. Record the public decisions without credentials.
3. Create a **Desktop app** OAuth client using Google's
   [desktop instructions](https://developers.google.com/identity/protocols/oauth2/native-app).
   Record its public client ID for reviewed build configuration. The implementation
   uses PKCE and no client secret; never paste tokens, codes or downloaded credential
   files into chat, Git or a PR.
4. Arrange production branding, home/privacy URLs, domain and support identity as
   required by the console. Testing status is not a permanent public-release plan;
   refresh invalidation must be tested. No production approval is implied by client creation.

## Reviewed activation and isolated verification

After identities and test-client setup are ready, authorize an activation follow-up.
Wire a validated GoogleOAuthConfiguration into the composition root and choose the
correct credential namespace. Add justified sandbox network client/server entitlements
in that review; the server entitlement alone does not confine a listener to loopback.
The code explicitly binds 127.0.0.1, but signed sandbox behavior must be exercised.
Do not add end-user client-ID/secret entry fields or silently enable an environment override.

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
