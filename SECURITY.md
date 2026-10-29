# Security policy

MacHandle is in pre-release development. No version is currently represented as
production-ready or independently security-audited.

Do not post credentials or personal data in public issues. Use GitHub's private
vulnerability reporting entry under this repository's Security tab if available.
If private reporting is unavailable, open an issue requesting a private reporting
channel without exploit details, logs, or sensitive information. No response-time
or dedicated security-team guarantee is offered at this stage.

If a credential is exposed, revoke it at its issuer immediately. Removing a file
from the current branch does not remove it from Git history or invalidate it.

See [the security model](docs/architecture/security-model.md) for trust boundaries and planned
controls. Report only synthetic, minimized reproduction steps. Public source,
passing checks, and scanner results are not proof of complete security.

Development rehearsal packages are not signed release evidence. Their checksums detect corruption,
not malicious replacement of an artifact and its checksum together. Report packaging/signature or
unexpected-permission issues privately using minimized synthetic evidence. Never attach signing
materials, credentials or personal support files. Before a public release the maintainer must verify
that the private reporting route works; current availability is not assumed. See the
[release gates](docs/development/release-engineering.md#owned-release-gates).
