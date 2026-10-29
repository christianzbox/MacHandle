# Privacy

MacHandle can request full Calendar permission only after you enable Calendar
discovery. macOS includes read/write authority in that grant. After selecting calendars,
a separate Read action retrieves bounded local availability, event titles, or event
details (title, location, notes), according to your chosen mode. Availability is the
default and hides details and identifiers. Reminders and Contacts have their own explicit opt-in,
resource selection and bounded local reads. MacHandle does not perform real Apple writes, access
Notes, connect external services, transmit content or collect analytics. Launch and navigation
do not request permission; resource discovery starts only after the corresponding opt-in.

Google OAuth/Keychain code is merged, but the app has no configured
Google service and its Connect control is disabled. It does not open an OAuth browser,
listen for callbacks, send Google requests or access Keychain. Activation requires
maintainer setup and signed verification. The implemented credential adapter uses a
private, non-synchronized data-protection Keychain item; local disconnect and remote
grant revocation are separate actions. See [activation requirements](docs/development/google-auth-setup.md).

Work package 09 provides internal destination/event API primitives with synthetic tests.
They are not exposed to the app, connected to source data or running against Google.
Calendar privacy cannot be proven by a title, ownership marker or event visibility;
source transfer remains blocked. See [destination boundaries](docs/architecture/decisions/0014-google-destination-client.md).

Work package 10 adds an isolated SQLite persistence library. The application does not
open it or persist Calendar results. Its future records contain private identity/mapping,
version, fingerprint and operation metadata, not event bodies or OAuth secrets. Files
use owner-only permissions; metadata is not database-encrypted. Restore always requires
revalidation. See [storage boundaries](docs/architecture/decisions/0015-sqlite-persistence.md).

The planned product will make each integration optional, show selected resources
and allowed operations, and explain what is shared with each destination. These
external-connection controls remain roadmap requirements. Calendar selection does not
authorize sharing. Names, selections, read results and preview history stay in memory. Changing access,
selection, read fields or dates clears displayed results; Clear Results does so explicitly.
Disabling discovery clears names/selections/results, and quit resets local opt-in. The OS grant is
managed separately in System Settings. Preview choices cannot grant actual access.

Apple Notes is experimental and unavailable. The [feasibility decision](docs/architecture/decisions/0031-notes-feasibility.md)
defers reading and editing until safe capabilities are verified with synthetic notes in a separate,
authorized test environment. This build has no Notes provider, tool or enable control and does not
request Automation permission for Notes. No extra account, permission or workaround enables it.
Engineering owns the [isolated acceptance gates](docs/development/notes-feasibility.md#isolated-runtime-gate);
the maintainer owns test setup and authorization. These gates have not been run, and the current
personal iCloud profile is not a development fixture. A verified read subset could precede editing;
no Notes capability or distribution approval is promised.

Never upload real personal information, credentials, exports, or diagnostic logs
to this public repository. Use synthetic examples for issues and contributions.
See [the privacy model](docs/architecture/privacy-model.md) for planned consent and minimization.
This document must be updated alongside changes to actual data handling.

Remote MCP remains unavailable under [ADR-0032](docs/architecture/decisions/0032-remote-mcp-readiness.md).
There is no remote listener, tunnel, account configuration or data transfer in this build. A future
remote connection would send explicitly permitted results beyond this Mac; relay/client data handling
must be reviewed and explained before activation. Tunnel access, OAuth consent, local resource/field
selection and exact write approval remain separate. No remote access is needed for local features.
