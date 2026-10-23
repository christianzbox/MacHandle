# Release policy

No installable public release exists. The development bundle is not signed with
Developer ID or notarized; do not distribute it as a production application.
Do not ask users to disable Gatekeeper or other macOS protections.

The intended milestones are foundation (PR-01–07), Google sync alpha (08–16), local
Calendar MCP beta (17–21), independent personal-information integrations (22–27),
and public distribution readiness (28–31 as feasible). Notes and plugin approval
must not block an otherwise safe, honestly scoped release.

Use semantic versioning; the current 0.1.0 build setting is a development value,
not a release announcement. Before release, define compatibility, data migrations,
Keychain identity, update strategy, signing/notarization, checksums, packaging,
rollback, and synthetic-account end-to-end validation. PR-30 owns implementation.
Signing and production OAuth credentials must never reach untrusted PR workflows.
Only the user may authorize publishing or merging; no release automation exists yet.
